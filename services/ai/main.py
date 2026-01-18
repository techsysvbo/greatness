from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "AI Service is running"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
@app.get("/recommend/events")
def recommend_events(zip_code: str = None):
    # Mock logic based on zip code
    if zip_code == "10001":
        return [
            {"id": 1, "title": "Tech Meetup NYC", "date": "2024-11-15", "location": "Manhattan, NY"},
            {"id": 2, "title": "Afro-Tech Summit", "date": "2024-12-01", "location": "Brooklyn, NY"}
        ]
    return [
        {"id": 3, "title": "Global Diaspora Conference", "date": "2024-11-20", "location": "Online"},
        {"id": 4, "title": "Local Cultural Festival", "date": "2024-11-25", "location": "City Center"}
    ]

@app.get("/recommend/interests")
def recommend_interests(profession: str = None):
    # Mock logic based on profession
    if profession and "Software" in profession:
        return [
            {"id": 1, "name": "Open Source Contributing"},
            {"id": 2, "name": "AI/ML Workshops"},
            {"id": 3, "name": "Tech Mentorship"}
        ]
    return [
        {"id": 4, "name": "Community Building"},
        {"id": 5, "name": "Cultural Exchange"},
        {"id": 6, "name": "Entrepreneurship"}
    ]
