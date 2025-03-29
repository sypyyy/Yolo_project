# Yolo_project
This project is an app which can use yolo to cache previously seen objects and its gps location, and use llm to help user navigate to any such locations based on user's need. Eg. User feels tired and ask for chairs, llm will ask the app to search the cache and return any seen chairs.

to run backend on localhost:
    fill the open_ai_key in settings.py
    cd into backend and run:
    python3 manage.py runserver 0.0.0.0:8000
    Test with curl -X POST -H "Content-Type: application/json" -d '{"text": "Hi?"}' http://127.0.0.1:8000/chat/

for iOS App,
there are two build target, YOLO and SpeechInteract, YOLO is the main target(entire app), SpeechInteract is only for when we want to test only the speech and llm interaction part. Since building and testing the entire app could take more time.
In the segmented control of the app, there is an option "dense", which I replaced a traditional yolo_classification model with a dense object detect model.
To use speech interaction tap the microphone button in the bottom bar.

