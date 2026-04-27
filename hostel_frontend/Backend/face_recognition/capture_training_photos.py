#!/usr/bin/env python3
"""
capture_training_photos.py
Capture 5 directional training photos from webcam or Pi camera.
Run this BEFORE train_model.py to get good quality photos.
Usage: python capture_training_photos.py
"""
import cv2
import os
import csv
import argparse
import numpy as np

try:
    from flask import Flask, request
except Exception:
    Flask = None
    request = None

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FACE_DATA_DIR = os.path.join(BASE_DIR, "face_data")
NAMES_FILE = os.path.join(FACE_DATA_DIR, "student_names.csv")
ALLOWED_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
DIRECTIONS    = [
    ("front", "Look STRAIGHT at camera"),
    ("left",  "Slowly turn face to the LEFT"),
    ("right", "Slowly turn face to the RIGHT"),
    ("up",    "Tilt face slightly UPWARD"),
    ("down",  "Tilt face slightly DOWNWARD"),
]
DIRECTION_KEYS = [direction for direction, _ in DIRECTIONS]


def _save_student_name(student_id, student_name):
    os.makedirs(FACE_DATA_DIR, exist_ok=True)

    student_id = (student_id or "").strip()
    student_name = (student_name or "").strip()
    if not student_id or not student_name:
        return

    all_names = {}
    if os.path.exists(NAMES_FILE):
        with open(NAMES_FILE, "r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                sid = (row.get("student_id") or "").strip().lower()
                sname = (row.get("student_name") or "").strip()
                if sid:
                    all_names[sid] = sname

    all_names[student_id.lower()] = student_name

    with open(NAMES_FILE, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["student_id", "student_name"])
        for sid, sname in sorted(all_names.items()):
            writer.writerow([sid, sname])


def _is_allowed_extension(filename):
    if not filename or "." not in filename:
        return False
    ext = filename.rsplit(".", 1)[1].lower()
    return ext in ALLOWED_IMAGE_EXTENSIONS


def _save_flask_uploads(student_id, student_name, files_by_direction):
    student_id = (student_id or "").strip()
    student_name = (student_name or "").strip()

    if not student_id or not student_name:
        return False, "student_id and student_name are required"

    save_dir = os.path.join(FACE_DATA_DIR, f"student_{student_id}")
    os.makedirs(save_dir, exist_ok=True)
    _save_student_name(student_id, student_name)

    for direction in DIRECTION_KEYS:
        uploaded = files_by_direction.get(direction)
        if uploaded is None or not uploaded.filename:
            return False, f"Missing file for direction: {direction}"
        if not _is_allowed_extension(uploaded.filename):
            return False, (
                f"Unsupported file extension for '{direction}'. "
                f"Allowed: {', '.join(sorted(ALLOWED_IMAGE_EXTENSIONS))}"
            )

        file_bytes = np.frombuffer(uploaded.read(), dtype=np.uint8)
        img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)
        if img is None:
            return False, f"Could not decode uploaded image for direction: {direction}"

        # Save as .jpg so train_model.py can use the files directly.
        save_path = os.path.join(save_dir, f"{direction}.jpg")
        ok = cv2.imwrite(save_path, img)
        if not ok:
            return False, f"Failed to save image for direction: {direction}"

    return True, save_dir


def create_flask_app():
    if Flask is None:
        raise RuntimeError("Flask is not installed. Install it with: pip install flask")

    app = Flask(__name__)

    @app.post("/api/capture-training-photos")
    def capture_training_photos_api():
        student_id = (request.form.get("student_id") or "").strip()
        student_name = (request.form.get("student_name") or "").strip()

        if not student_id or not student_name:
            return {"ok": False, "error": "student_id and student_name are required"}, 400

        files_by_direction = {
            direction: request.files.get(direction)
            for direction, _ in DIRECTIONS
        }
        success, detail = _save_flask_uploads(student_id, student_name, files_by_direction)
        if not success:
            return {"ok": False, "error": detail}, 400

        return {
            "ok": True,
            "student_id": student_id,
            "student_name": student_name,
            "saved_dir": detail,
            "saved_as": "jpg",
        }

    return app


def capture_photos(student_id, student_name):
    student_id = (student_id or "").strip()
    student_name = (student_name or "").strip()

    if not student_id or not student_name:
        print("[Error] student_id and student_name are required")
        return False

    save_dir = os.path.join(FACE_DATA_DIR, f"student_{student_id}")
    os.makedirs(save_dir, exist_ok=True)

    # Save student name to CSV so Flask/recognition code can read it.
    _save_student_name(student_id, student_name)
    print(f"  [OK] Name saved: {student_id} → {student_name}")

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    if not cap.isOpened():
        print("[Error] Cannot open camera")
        return False

    print(f"\nCapturing photos for: {student_name} (ID: {student_id})")
    print("=" * 55)

    captured = []

    for i, (direction, instruction) in enumerate(DIRECTIONS):
        print(f"\nStep {i+1}/5 → {direction.upper()}")
        print(f"  {instruction}")
        print(f"  Press SPACE to capture | Press Q to quit")

        while True:
            ret, frame = cap.read()
            if not ret:
                continue

            h, w   = frame.shape[:2]
            cx, cy = w // 2, h // 2

            # Draw face oval guide
            cv2.ellipse(frame, (cx, cy), (130, 170), 0, 0, 360, (0, 255, 0), 2)

            # Draw corner markers
            for px, py in [(cx-130, cy), (cx+130, cy), (cx, cy-170), (cx, cy+170)]:
                cv2.circle(frame, (px, py), 6, (0, 255, 255), -1)

            # Show text
            cv2.putText(frame, instruction,
                (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.75, (0, 255, 255), 2)
            cv2.putText(frame, f"Step {i+1}/5  |  SPACE = Capture  |  Q = Quit",
                (20, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)
            cv2.putText(frame, f"Student: {student_name}",
                (20, h - 50), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 255, 0), 2)
            cv2.putText(frame, f"Direction: {direction.upper()}",
                (20, h - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 255, 0), 2)

             # Show captured thumbnails bottom right
            for j, cap_img in enumerate(captured):
                thumb   = cv2.resize(cap_img, (60, 60))
                x_start = w - (j + 1) * 70
                if x_start >= 0 and x_start + 60 <= w:
                    frame[h-70:h-10, x_start:x_start+60] = thumb

            cv2.imshow("Capture Training Photos", frame)
            key = cv2.waitKey(1) & 0xFF

            if key == ord('q'):
                print("\n[Quit]")
                cap.release()
                cv2.destroyAllWindows()
                return False

            elif key == ord(' '):
                save_path = os.path.join(save_dir, f"{direction}.jpg")
                cv2.imwrite(save_path, frame)
                captured.append(cv2.resize(frame, (60, 60)))
                print(f"  ✅ Captured and saved: {save_path}")

                # Flash effect
                flash = frame.copy()
                flash[:] = (255, 255, 255)
                cv2.imshow("Capture Training Photos", flash)
                cv2.waitKey(250)
                break

    cap.release()
    cv2.destroyAllWindows()

    print(f"\n✅ All 5 photos captured for {student_name}!")
    print(f"   Saved in: {save_dir}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Capture 5 directional training photos for one or more students."
    )
    parser.add_argument("--student-id", help="Student ID for single-run mode")
    parser.add_argument("--student-name", help="Student name for single-run mode")
    parser.add_argument("--flask", action="store_true", help="Run as Flask API service")
    parser.add_argument("--host", default="127.0.0.1", help="Flask host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=5000, help="Flask port (default: 5000)")
    args = parser.parse_args()

    if args.flask:
        if Flask is None:
            print("[Error] Flask is not installed. Install it with: pip install flask")
            return

        app = create_flask_app()
        print(f"[Flask] Starting API on http://{args.host}:{args.port}")
        print("[Flask] Endpoint: POST /api/capture-training-photos")
        app.run(host=args.host, port=args.port)
        return

    if (args.student_id and not args.student_name) or (args.student_name and not args.student_id):
        print("[Error] Use --student-id and --student-name together")
        return

    if args.student_id and args.student_name:
        success = capture_photos(args.student_id.strip(), args.student_name.strip())
        if success:
            print("\nAll done! Now run:")
            print("  python train_model.py")
        return

    print("=" * 55)
    print("   TRAINING PHOTO CAPTURE TOOL")
    print("=" * 55)
    print("\nThis tool captures 5 directional photos per student")
    print("directly from the webcam for best accuracy.\n")

    while True:
        student_id   = input("Enter student ID   (e.g. 101)       : ").strip()
        student_name = input("Enter student name (e.g. Rahul Shah) : ").strip()

        if not student_id or not student_name:
            print("[Error] ID and name cannot be empty\n")
            continue

        success = capture_photos(student_id, student_name)

        if success:
            print("\n" + "=" * 55)
            another = input("Capture another student? (y/n): ").strip().lower()
            if another != 'y':
                break
        else:
            break

    print("\nAll done! Now run:")
    print("  python train_model.py")


if __name__ == "__main__":
    main()