#!/usr/bin/env python3
"""
train_model.py
Run this on your SERVER (not Pi) after student photos are uploaded.
pip install deepface opencv-python numpy tensorflow tf-keras
"""

import os
import cv2
import pickle
import numpy as np
import csv
from deepface import DeepFace

FACE_DATA_DIR  = os.path.join(os.path.dirname(os.path.abspath(__file__)), "face_data")
MODEL_OUTPUT   = os.path.join(os.path.dirname(os.path.abspath(__file__)), "trained_model.pkl")
DIRECTIONS     = ["front", "left", "right", "up", "down"]
DEEPFACE_MODEL = "Facenet512"
SUPPORTED_IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp"]


def _load_allowed_student_ids():
    """Load known student IDs from face_data/student_names.csv if available."""
    names_file = os.path.join(FACE_DATA_DIR, "student_names.csv")
    if not os.path.exists(names_file):
        return None

    allowed_ids = set()
    with open(names_file, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sid = (row.get("student_id") or "").strip().lower()
            if sid:
                allowed_ids.add(sid)

    return allowed_ids or None


def _find_direction_image(folder_path, direction):
    """Find first available direction image across supported extensions."""
    for ext in SUPPORTED_IMAGE_EXTENSIONS:
        candidate = os.path.join(folder_path, f"{direction}{ext}")
        if os.path.exists(candidate):
            return candidate
    return None


def preprocess_face(img_bgr):
    """Resize and enhance face — must be identical in train and recognize."""
    face = cv2.resize(img_bgr, (160, 160))
    lab  = cv2.cvtColor(face, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l = clahe.apply(l)
    return cv2.cvtColor(cv2.merge((l, a, b)), cv2.COLOR_LAB2BGR)


def augment_image(img):
    """Create 6 variations of each photo."""
    h, w = img.shape[:2]
    M1   = cv2.getRotationMatrix2D((w//2, h//2),  8, 1.0)
    M2   = cv2.getRotationMatrix2D((w//2, h//2), -8, 1.0)
    return [
        img,
        cv2.convertScaleAbs(img, alpha=1.3, beta=20),   # brighter
        cv2.convertScaleAbs(img, alpha=0.7, beta=-20),  # darker
        cv2.flip(img, 1),                                # mirror
        cv2.warpAffine(img, M1, (w, h)),                 # rotate right
        cv2.warpAffine(img, M2, (w, h)),                 # rotate left
    ]


def get_embedding(img_bgr):
    """Detect face, crop it, preprocess and get Facenet512 embedding."""
    try:
        faces = DeepFace.extract_faces(
            img_path          = img_bgr,
            detector_backend  = "opencv",
            enforce_detection = False,
        )
        if not faces or faces[0]["confidence"] < 0.5:
            return None

        fa       = faces[0]["facial_area"]
        x, y, w, h = fa["x"], fa["y"], fa["w"], fa["h"]
        pad      = int(w * 0.25)
        x1, y1   = max(0, x - pad), max(0, y - pad)
        x2, y2   = min(img_bgr.shape[1], x + w + pad), min(img_bgr.shape[0], y + h + pad)
        face_crop = img_bgr[y1:y2, x1:x2]

        if face_crop.size == 0:
            return None

        result = DeepFace.represent(
            img_path          = preprocess_face(face_crop),
            model_name        = DEEPFACE_MODEL,
            enforce_detection = False,
            detector_backend  = "skip",
        )
        if result:
            return np.array(result[0]["embedding"])
    except Exception as e:
        print(f"    [Error] {e}")
    return None


def train_model():
    known_embeddings = []
    known_labels     = []
    allowed_student_ids = _load_allowed_student_ids()

    if not os.path.exists(FACE_DATA_DIR):
        print(f"[Error] face_data folder not found: {FACE_DATA_DIR}")
        return

    student_folders = sorted([
        f for f in os.listdir(FACE_DATA_DIR)
        if os.path.isdir(os.path.join(FACE_DATA_DIR, f)) and f.startswith("student_")
    ])

    if not student_folders:
        print("[Error] No student folders found in face_data/")
        return

    print(f"[Train] Model   : {DEEPFACE_MODEL}")
    print(f"[Train] Students: {len(student_folders)}\n")
    if allowed_student_ids is not None:
        print(f"[Train] Using names CSV whitelist: {len(allowed_student_ids)} allowed IDs")

    for folder_name in student_folders:
        student_id  = folder_name.replace("student_", "")
        student_id_key = student_id.strip().lower()

        if allowed_student_ids is not None and student_id_key not in allowed_student_ids:
            print(f"  [Skip] {student_id}: not present in student_names.csv")
            continue

        folder_path = os.path.join(FACE_DATA_DIR, folder_name)
        embeddings  = []

        for direction in DIRECTIONS:
            img_path = _find_direction_image(folder_path, direction)
            if not img_path:
                print(f"  [Skip] {direction} missing for {student_id}")
                continue

            img = cv2.imread(img_path)
            if img is None:
                print(f"  [Skip] Cannot read {direction} for {student_id}")
                continue

            for aug in augment_image(img):
                emb = get_embedding(aug)
                if emb is not None:
                    embeddings.append(emb)

        if embeddings:
            # Limit to 10 embeddings per student to keep model fast
            if len(embeddings) > 10:
                embeddings = embeddings[:10]

            known_embeddings.extend(embeddings)
            known_labels.extend([student_id] * len(embeddings))
            print(f"  [OK] {student_id}: {len(embeddings)} embeddings")
        else:
            print(f"  [Fail] {student_id}: no face detected in photos")
    if not known_embeddings:
        print("\n[Error] No embeddings generated. Check your photos.")
        return

    with open(MODEL_OUTPUT, "wb") as f:
        pickle.dump({
            "embeddings": known_embeddings,
            "labels":     known_labels,
            "model":      DEEPFACE_MODEL,
        }, f)

    print(f"\n[Train] ✅ Done!")
    print(f"  Students  : {len(set(known_labels))}")
    print(f"  Embeddings: {len(known_embeddings)}")
    print(f"  Saved to  : {MODEL_OUTPUT}")


if __name__ == "__main__":
    train_model()