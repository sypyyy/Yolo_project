# Yolo_project
to run backend:
    fill the open_ai_key in settings.py
    cd into backend and run:
    python3 manage.py runserver 0.0.0.0:8000
    Test with curl -X POST -H "Content-Type: application/json" -d '{"text": "Hi?"}' http://127.0.0.1:8000/chat/
