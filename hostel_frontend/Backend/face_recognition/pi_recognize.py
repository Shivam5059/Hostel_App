#!/usr/bin/env python3
"""
pi_recognize.py
Run this on Raspberry Pi 4B with 12MP camera module.
Detects face, matches with trained model, displays student name.
"""

import os
import argparse
import cv2
import pickle
import numpy as np
import shutil
import subprocess
import threading
import time
from deepface import DeepFace
from datetime import datetime, timedelta
import csv

try:
    import requests
except Exception:
    requests = None

# ── Configuration ─────────────────────────────────────────────────────────────
BASE_DIR             = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH           = os.path.join(BASE_DIR, "trained_model.pkl")
FLASK_API_URL        = os.getenv("FLASK_API_URL", "http://10.44.148.170:3000/api/recognition-event")
AUTH_TOKEN           = os.getenv("FLASK_API_TOKEN", "")

SIMILARITY_THRESHOLD = 0.60   # lower if showing Unknown, raise if wrong person shown
LOG_CONFIDENCE_GATE  = float(os.getenv("LOG_CONFIDENCE_GATE", "75"))
COOLDOWN_SECONDS     = 15      # seconds before same student can be logged again
FRAME_SKIP           = 3      # process every 3rd frame (saves CPU on Pi)
MIN_FACE_SIZE        = 80     # ignore faces smaller than this (too far away)
DISPLAY_WIDTH        = 800    # display window width
DISPLAY_HEIGHT       = 600    # display window height

ENTRY_LOG_FILE       = os.path.join(BASE_DIR, "entry_logs.csv")
ENTRY_FALLBACK_FILE  = os.path.join(BASE_DIR, "entry_logs_fallback.csv")

def check_and_update_model():
    """Download model from Flask server if newer version available."""
    if not FLASK_API_URL:
        return

    base_url = FLASK_API_URL.rsplit("/api/", 1)[0]

    try:
        res  = requests.get(f"{base_url}/api/model/status", timeout=5)
        data = res.json()

        if not data.get("exists"):
            print("[Model] No model on server yet")
            return

        server_ts = data.get("timestamp", 0)

        # Compare with local
        if os.path.exists(MODEL_PATH):
            local_ts = os.path.getmtime(MODEL_PATH)
            if local_ts >= server_ts:
                print("[Model] Already up to date")
                return

        # Download new model
        print("[Model] Newer model found. Downloading...")
        res = requests.get(
            f"{base_url}/api/model/download",
            timeout=120,
            stream=True,
        )
        if res.status_code == 200:
            with open(MODEL_PATH, "wb") as f:
                for chunk in res.iter_content(chunk_size=8192):
                    f.write(chunk)
            print("[Model] Downloaded successfully!")
        else:
            print(f"[Model] Download failed: {res.status_code}")

    except Exception as e:
        print(f"[Model] Could not reach server: {e}")


# Student ID -> Real Name mapping
_names_file = os.path.join(BASE_DIR, "face_data", "student_names.csv")
try:
    _names_mtime = os.path.getmtime(_names_file)
except OSError:
    _names_mtime = None


def load_student_names():
    names = {}
    if os.path.exists(_names_file):
        with open(_names_file, "r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                sid = (row.get("student_id") or "").strip().lower()
                sname = (row.get("student_name") or "").strip()
                if sid:
                    names[sid] = sname
        print(f"[Pi] Loaded {len(names)} student names from CSV")
    else:
        print("[Pi] No student_names.csv found - will show IDs only")
    return names


STUDENT_NAMES = load_student_names()


def refresh_student_names_if_changed():
    """Reload name map if the CSV was created/updated while the app is running."""
    global STUDENT_NAMES, _names_mtime
    try:
        current_mtime = os.path.getmtime(_names_file)
    except OSError:
        current_mtime = None

    if current_mtime != _names_mtime:
        STUDENT_NAMES = load_student_names()
        _names_mtime = current_mtime
# ──────────────────────────────────────────────────────────────────────────────


def preprocess_face(img_bgr):
    """MUST be identical to train_model.py preprocessing."""
    face = cv2.resize(img_bgr, (160, 160))
    lab  = cv2.cvtColor(face, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l = clahe.apply(l)
    return cv2.cvtColor(cv2.merge((l, a, b)), cv2.COLOR_LAB2BGR)


def cosine_similarity(a, b):
    a, b = np.array(a), np.array(b)
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


def get_embedding(face_bgr):
    """Get Facenet512 embedding from a cropped face image."""
    try:
        result = DeepFace.represent(
            img_path          = preprocess_face(face_bgr),
            model_name        = "Facenet512",
            enforce_detection = False,
            detector_backend  = "skip",  # already cropped
        )
        if result:
            return np.array(result[0]["embedding"])
    except Exception:
        pass
    return None


def find_best_match(embedding, known_embeddings, known_labels):
    """
    Match embedding against all known students.
    Uses top-3 average score per student for reliability.
    """
    if not known_embeddings or not known_labels:
        return None, None

    student_scores = {}
    for known_emb, label in zip(known_embeddings, known_labels):
        score = cosine_similarity(embedding, known_emb)
        if label not in student_scores:
            student_scores[label] = []
        student_scores[label].append(score)

    student_avg = {}
    for label, scores in student_scores.items():
        top3 = sorted(scores, reverse=True)[:3]
        student_avg[label] = np.mean(top3)

    if not student_avg:
        return None, None

    best_label = max(student_avg, key=student_avg.get)
    best_score = student_avg[best_label]

    if best_score >= SIMILARITY_THRESHOLD:
        return best_label, round(best_score * 100, 1)
    return None, None


def get_display_name(student_id):
    """Get real name from student ID, fallback to ID if not in map."""
    refresh_student_names_if_changed()

    sid = (student_id or "").strip()
    sid_lower = sid.lower()
    if sid_lower in STUDENT_NAMES:
        return STUDENT_NAMES[sid_lower]

    return f"Student {student_id}"


def lookup_student_name(student_id):
    """Return the mapped name for a student ID without starting recognition."""
    refresh_student_names_if_changed()
    sid_lower = (student_id or "").strip().lower()
    if not sid_lower:
        return None
    return STUDENT_NAMES.get(sid_lower)


def send_event_to_flask(payload):
    """Send recognition event to Flask backend if endpoint is configured."""
    if not FLASK_API_URL:
        print("  [Warn] FLASK_API_URL not configured")
        return

    if requests is None:
        print("  [Warn] requests is not installed; skipping Flask API call")
        return

    headers = {"Content-Type": "application/json"}
    if AUTH_TOKEN:
        headers["Authorization"] = f"Bearer {AUTH_TOKEN}"

    try:
        print(f"  [API] Sending to {FLASK_API_URL}: {payload}")
        response = requests.post(FLASK_API_URL, json=payload, headers=headers, timeout=5)
        print(f"  [API] Response: {response.status_code} - {response.text[:200]}")
        if response.status_code >= 400:
            print(f"  [Warn] Flask API error {response.status_code}: {response.text[:120]}")
        elif response.status_code == 201:
            print(f"  [API] ✓ Event logged successfully in database")
    except Exception as e:
        print(f"  [Warn] Flask API request failed: {e}")


def _append_log_row(log_file, row):
    """Append one CSV log row, writing header when the file is new."""
    file_exists = os.path.exists(log_file) and os.path.getsize(log_file) > 0
    with open(log_file, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["student_id", "student_name", "confidence", "timestamp", "event_type"])
        writer.writerow(row)

def log_entry(student_id, student_name, confidence, entry_type):
    """Log entry or exit to terminal and CSV file."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    symbol    = "🟢 ENTRY" if entry_type == "entry" else "🔴 EXIT"

    # Print to terminal
    print(f"\n{'='*50}")
    print(f"  {symbol} DETECTED")
    clean_name = (student_name or "").strip()
    clean_id = (student_id or "").strip()
    print(f"  Name       : {clean_name}")
    print(f"  Student ID : {clean_id}")
    print(f"  Confidence : {confidence}%")
    print(f"  Time       : {timestamp}")
    print(f"  Type       : {entry_type.upper()}")
    print(f"{'='*50}\n")

    # Save to CSV. If primary log is locked (common on Windows), use fallback.
    row = [clean_id, clean_name, confidence, timestamp, entry_type]

    try:
        _append_log_row(ENTRY_LOG_FILE, row)
    except PermissionError:
        print(f"  [Warn] Log file locked: {ENTRY_LOG_FILE}")
        print(f"  [Warn] Writing logs to fallback file: {ENTRY_FALLBACK_FILE}")
        try:
            _append_log_row(ENTRY_FALLBACK_FILE, row)
        except Exception as e:
            print(f"  [Warn] Could not write fallback log file: {e}")
    except Exception as e:
        print(f"  [Warn] Failed to write log file: {e}")

    payload = {
        "student_id": clean_id,
        "student_name": clean_name,
        "confidence": confidence,
        "timestamp": timestamp,
        "event_type": entry_type,
    }
    send_event_to_flask(payload)

def draw_label(frame, text, x, y, color):
    """Draw filled rectangle with text above face box."""
    font       = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.7
    thickness  = 2
    (tw, th), _ = cv2.getTextSize(text, font, font_scale, thickness)
    # filled background for text
    cv2.rectangle(frame, (x, y - th - 12), (x + tw + 10, y), color, -1)
    cv2.putText(frame, text, (x + 5, y - 6),
                font, font_scale, (255, 255, 255), thickness)


class RpiMjpegCamera:
    """Read Pi camera frames through rpicam-vid and decode MJPEG in OpenCV."""

    def __init__(self, width=1280, height=720, framerate=30):
        self.width = width
        self.height = height
        self.framerate = framerate
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._latest_frame = None
        self._startup_error = None
        self._process = None
        self._thread = None

        camera_cmd = shutil.which("rpicam-vid") or shutil.which("libcamera-vid")
        if not camera_cmd:
            raise RuntimeError("rpicam-vid/libcamera-vid not found")

        command = [
            camera_cmd,
            "--timeout", "0",
            "--nopreview",
            "--inline",
            "--codec", "mjpeg",
            "--width", str(self.width),
            "--height", str(self.height),
            "--framerate", str(self.framerate),
            "--output", "-",
        ]

        self._process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        self._thread = threading.Thread(target=self._reader_loop, daemon=True)
        self._thread.start()

    def _reader_loop(self):
        buffer = bytearray()
        while not self._stop_event.is_set():
            if self._process is None or self._process.stdout is None:
                break

            chunk = self._process.stdout.read(4096)
            if not chunk:
                if self._process.poll() is not None:
                    err = b""
                    try:
                        err = self._process.stderr.read() if self._process.stderr else b""
                    except Exception:
                        err = b""
                    err_msg = (err.decode(errors="ignore") if isinstance(err, (bytes, bytearray)) else str(err)).strip()
                    if err_msg:
                        self._startup_error = err_msg.splitlines()[-1]
                    else:
                        self._startup_error = "rpicam process exited before frames were available"
                break

            buffer.extend(chunk)

            while True:
                start = buffer.find(b"\xff\xd8")
                if start == -1:
                    if len(buffer) > 2_000_000:
                        buffer.clear()
                    break

                end = buffer.find(b"\xff\xd9", start + 2)
                if end == -1:
                    if start > 0:
                        del buffer[:start]
                    break

                frame_bytes = bytes(buffer[start:end + 2])
                del buffer[:end + 2]

                frame_array = np.frombuffer(frame_bytes, dtype=np.uint8)
                frame = cv2.imdecode(frame_array, cv2.IMREAD_COLOR)
                if frame is not None:
                    with self._lock:
                        self._latest_frame = frame

        self._stop_event.set()

    def read(self):
        with self._lock:
            if self._latest_frame is None:
                return False, None
            return True, self._latest_frame.copy()

    def get_error(self):
        return self._startup_error

    def release(self):
        self._stop_event.set()
        if self._process is not None:
            try:
                self._process.terminate()
            except Exception:
                pass
            try:
                self._process.wait(timeout=2)
            except Exception:
                try:
                    self._process.kill()
                except Exception:
                    pass
        if self._thread is not None and self._thread.is_alive():
            self._thread.join(timeout=2)


class RpiJpegSnapshotCamera:
    """Fallback camera reader using one-shot JPEG captures via rpicam-jpeg."""

    def __init__(self, width=1280, height=720):
        self.width = width
        self.height = height
        self._error = None
        self._camera_cmd = shutil.which("rpicam-jpeg") or shutil.which("libcamera-jpeg")
        if not self._camera_cmd:
            raise RuntimeError("rpicam-jpeg/libcamera-jpeg not found")

    def read(self):
        command = [
            self._camera_cmd,
            "--timeout", "1000",
            "--nopreview",
            "--width", str(self.width),
            "--height", str(self.height),
            "--output", "-",
        ]

        try:
            result = subprocess.run(
                command,
                check=True,
                capture_output=True,
                timeout=8,
            )
            frame_array = np.frombuffer(result.stdout, dtype=np.uint8)
            frame = cv2.imdecode(frame_array, cv2.IMREAD_COLOR)
            if frame is None:
                self._error = "Failed to decode JPEG frame"
                return False, None
            return True, frame
        except Exception as e:
            self._error = str(e)
            return False, None

    def get_error(self):
        return self._error

    def release(self):
        pass


def open_pi_camera():
    """Try Pi camera through rpicam-vid first, fallback to USB camera."""
    picam = None
    try:
        picam = RpiMjpegCamera(width=1280, height=720, framerate=30)
        print("[Pi] Using rpicam-vid MJPEG stream (Pi camera)")

        # Camera startup can take several seconds on Pi; wait long enough.
        start = time.time()
        startup_timeout_seconds = 15
        while (time.time() - start) < startup_timeout_seconds:
            ret, _frame = picam.read()
            if ret:
                return picam
            if picam.get_error():
                raise RuntimeError(picam.get_error())
            time.sleep(0.05)

        raise RuntimeError("Timed out waiting for first Pi camera frame")
    except Exception as e:
        if picam is not None:
            try:
                picam.release()
            except Exception:
                pass
        print(f"[Pi] rpicam-vid unavailable: {e}")

    # Fallback to single-frame JPEG captures on Pi camera.
    try:
        jpeg_cam = RpiJpegSnapshotCamera(width=1280, height=720)
        ret, _frame = jpeg_cam.read()
        if ret:
            print("[Pi] Using rpicam-jpeg snapshot mode (Pi camera)")
            return jpeg_cam
        if jpeg_cam.get_error():
            raise RuntimeError(jpeg_cam.get_error())
        raise RuntimeError("Unable to capture initial JPEG frame")
    except Exception as e:
        print(f"[Pi] rpicam-jpeg unavailable: {e}")

    # Fallback to OpenCV VideoCapture
    cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
    if cap.isOpened():
        cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        cap.set(cv2.CAP_PROP_FPS, 30)
        print("[Pi] Using OpenCV VideoCapture (camera index 0)")
        return cap

    return None


def main():
    parser = argparse.ArgumentParser(description="Raspberry Pi face recognition tool")
    parser.add_argument("--lookup-name", help="Print the mapped student name for a student ID and exit")
    args = parser.parse_args()

    if args.lookup_name:
        name = lookup_student_name(args.lookup_name)
        if name:
            print(f"{args.lookup_name.strip()} -> {name}")
        else:
            print(f"{args.lookup_name.strip()} -> [not found]")
        return

    # Auto download latest model from Flask server
    check_and_update_model()
    # ── Load trained model ──
    print("[Pi] Loading trained model...")
    if not os.path.exists(MODEL_PATH):
        print(f"[Error] Model not found: {MODEL_PATH}")
        print("  Copy trained_model.pkl to /home/pi/hostel_app/")
        return

    with open(MODEL_PATH, "rb") as f:
        data = pickle.load(f)

    known_embeddings = data.get("embeddings", [])
    known_labels     = data.get("labels", [])
    if not known_embeddings or not known_labels:
        print("[Error] Model is empty or invalid. Re-run train_model.py")
        return

    print(f"[Pi] Students  : {len(set(known_labels))}")
    print(f"[Pi] Embeddings: {len(known_labels)}")

    # ── Open camera ──
    camera = open_pi_camera()
    if camera is None:
        print("[Error] No camera found")
        return

    # ── Face detector ──
    face_det = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )

    print("\n[Pi] Recognition started. Press Q to quit.\n")

    frame_num   = 0
    last_logged   = {}   # student_id → last log time
    current_face  = None
    student_state = {}   # student_id → "entry" or "exit"

    while True:
        # ── Read frame ──
        ret, frame = camera.read()
        if not ret:
            if hasattr(camera, "get_error"):
                cam_error = camera.get_error()
                if cam_error:
                    print(f"[Error] Pi camera stream failed: {cam_error}")
                    break
            continue

        frame_num += 1

        # Show every frame but only process every FRAME_SKIP frames
        display_frame = cv2.resize(frame, (DISPLAY_WIDTH, DISPLAY_HEIGHT))

        if frame_num % FRAME_SKIP != 0:
            cv2.imshow("Hostel Entry - Face Recognition", display_frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
            continue

        # ── Detect faces ──
        gray    = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray_eq = cv2.equalizeHist(gray)
        faces   = face_det.detectMultiScale(
            gray_eq,
            scaleFactor  = 1.1,
            minNeighbors = 5,
            minSize      = (MIN_FACE_SIZE, MIN_FACE_SIZE),
        )

        for (x, y, w, h) in faces:
            # Crop face with padding
            pad = int(w * 0.25)
            x1  = max(0, x - pad)
            y1  = max(0, y - pad)
            x2  = min(frame.shape[1], x + w + pad)
            y2  = min(frame.shape[0], y + h + pad)
            face_crop = frame[y1:y2, x1:x2]

            if face_crop.size == 0:
                continue

            # Get embedding
            embedding = get_embedding(face_crop)
            if embedding is None:
                continue

            # Match against model
            student_id, confidence = find_best_match(
                embedding, known_embeddings, known_labels
            )

            # Scale face coordinates to display size
            scale_x = DISPLAY_WIDTH  / frame.shape[1]
            scale_y = DISPLAY_HEIGHT / frame.shape[0]
            dx  = int(x  * scale_x)
            dy  = int(y  * scale_y)
            dw  = int(w  * scale_x)
            dh  = int(h  * scale_y)

            if student_id:
                student_name = get_display_name(student_id)

                now  = datetime.now()
                last = last_logged.get(student_id)

                if confidence < LOG_CONFIDENCE_GATE:
                    current_face = None
                    color = (0, 165, 255)
                    label = f"Low confidence: {student_name} | {confidence}%"

                    cv2.rectangle(display_frame, (dx, dy), (dx + dw, dy + dh), color, 2)
                    draw_label(display_frame, label, dx, dy, color)
                    continue

                if current_face != student_id:
                    current_face = student_id

                    if not last or (now - last) > timedelta(seconds=COOLDOWN_SECONDS):
                        # Determine entry or exit by alternating
                        last_type = student_state.get(student_id, "exit")
                        if last_type == "exit":
                            entry_type = "entry"
                        else:
                            entry_type = "exit"

                        # Save new state
                        student_state[student_id] = entry_type

                        log_entry(student_id, student_name, confidence, entry_type)
                        last_logged[student_id] = now

                # Show different color for entry vs exit
                last_type = student_state.get(student_id, "entry")
                color     = (0, 200, 0) if last_type == "entry" else (0, 165, 255)
                label     = f"{student_name} | {last_type.upper()} | {confidence}%"

            else:
                current_face = None
                color        = (0, 0, 200)
                label        = "Unknown"

            # Draw face box and name label on display frame
            cv2.rectangle(display_frame, (dx, dy), (dx + dw, dy + dh), color, 2)
            draw_label(display_frame, label, dx, dy, color)

        cv2.imshow("Hostel Entry - Face Recognition", display_frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Cleanup
    camera.release()
    cv2.destroyAllWindows()
    print("\n[Pi] Stopped.")


if __name__ == "__main__":
    main()