from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
import openai
from openai import OpenAI
from openai import AssistantEventHandler
from typing_extensions import override
from typing import Optional
import threading

from . import settings

#curl -X POST -H "Content-Type: application/json" -d '{"tool_output": [{"tool_call_id": "call_egYDx1LHukDAOUoNW1QkdE6M", "output": "55"}], "run_id": "run_4fIyCtgnlLzymgtwTUKvddWd"}' http://127.0.0.1:8000/client_action_done/
# Create Assistant
client = OpenAI(api_key = settings.OPENAI_API_KEY)

COCO_CLASS_NAMES = """
[
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
    "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
    "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
    "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
    "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
    "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair",
    "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
    "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator",
    "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
]
"""

assistant = client.beta.assistants.create(
  instructions="""
  you are a daily assistant for visually impaired users.
  Right now your abilities are search for places or objects with available keywords provided and get directions to them.
  """,
  model="gpt-4o",
  tools=[
    {
      "type": "function",
      "function": {
      "name": "search_recently_seen_objects",
      "description": "Search for recently seen objects or places",
      "strict": True,
      "parameters": {
        "type": "object",
        "required": [
          "keyword"
        ],
        "properties": {
          "keyword": {
            "type": "string",
            "description": "The keyword to search for recently seen objects or places"
          }
        },
        "additionalProperties": False
      }
    }
    },
    {
      "type": "function",
      "function": {
        "name": "get_available_keywords",
        "description": "Get available keywords for searching places",
        "strict": True,
        "parameters": {
          "type": "object",
          "properties": {},
          "additionalProperties": False,
          "required": []
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "navigate_user_to",
        "description": "Navigate the user to a coordinate, confirm with user first before calling",
        "strict": True,
        "parameters": {
          "type": "object",
          "required": [
            "latitude",
            "longitude",
          ],
          "properties": {
            "latitude": {
              "type": "number"
            },
            "longitude": {
              "type": "number"
            }
          },
          "additionalProperties": False
        }
      }
    }
  ]
)

class EventHandler(AssistantEventHandler):    
  @override
  def on_text_created(self, text) -> None:
    print(f"\nassistant > ", end="", flush=True)
      
  @override
  def on_text_delta(self, delta, snapshot):
    print(delta.value, end="", flush=True)
      
  def on_tool_call_created(self, tool_call):
    print(f"\nassistant > {tool_call.type}\n", flush=True)
  
  def on_tool_call_delta(self, delta, snapshot):
    if delta.type == 'code_interpreter':
      if delta.code_interpreter.input:
        print(delta.code_interpreter.input, end="", flush=True)
      if delta.code_interpreter.outputs:
        print(f"\n\noutput >", flush=True)
        for output in delta.code_interpreter.outputs:
          if output.type == "logs":
            print(f"\n{output.logs}", flush=True)

# Context history storage (in-memory for simplicity)
context_history = []

#Thread.id : toolOutput Array
tool_outputs_cache_mapping = {}

thread = client.beta.threads.create()

@csrf_exempt
def assistant_service(request):
    global context_history  # Maintain context
    
    if request.method == "POST":
      try:
            
            response = {
                   "thread_id": thread.id,
                   "message": "",
                   "required_actions": [],
            }
            data = json.loads(request.body)

            user_input = data.get("text", "")

            #If the request is a user sent msg
            if user_input:
                #return JsonResponse({"error": "No input provided."}, status=400)
            
                # Add user input to context history
            
                # testing
            
                message = client.beta.threads.messages.create(
                thread_id=thread.id,
                role="user",
                content=user_input
                )
                ########
                run = client.beta.threads.runs.create_and_poll(
                thread_id=thread.id,
                assistant_id=assistant.id,
                )
                while run.status != 'completed' and run.status != 'failed':
                    print(f"run status 1 is{run.status}")
                    if run.required_action != None:
                      shouldReturn = newActionRequired(run=run, response=response)
                      if shouldReturn:
                          return JsonResponse(response)
                    run = client.beta.threads.runs.retrieve(
                      thread_id=thread.id,
                      run_id = run.id
                      )
                      # Submit all tool outputs at once after collecting them in a list
                      #curl -X POST -H "Content-Type: application/json" -d ‘{“tool_output”: [{“tool_call_id“ : “call_52v3rd3RWZOxUxhDlM6oG9sv”, “output”: “55”}]}’ http://127.0.0.1:8000/chat/
                #Out of the loop, means this run is completed
                if run.status == 'completed':
                    messages = client.beta.threads.messages.list(
                        thread_id=thread.id
                    )
                    response["message"] = messages.data[0].content[0].text.value
                    print(messages.data[0])
                else:
                    print("RUN status 3")
                    print(run.status)
                return JsonResponse(response)   
            else:
                return JsonResponse({"error": f"User did not speak"}, status=400)
      except Exception as e:
        print(f"Exception!!!!!! {str(e)}")
        return JsonResponse({"error": f"Failed to add user input: {str(e)}"}, status=500)
    else:
        return JsonResponse({"error": "Invalid request method."}, status=400)


@csrf_exempt
def refresh_thread(request):
    global thread
    try:
      client.beta.threads.delete(thread.id)
    except Exception as e:
      print(f"Exception!!!!!! {str(e)}")
    thread = client.beta.threads.create()
    return JsonResponse({"good": "New thread created."}, status=200)


@csrf_exempt
def assistant_tool_completion_from_client(request):
    global context_history  # Maintain context

    if request.method == "POST":
        #try:
            response = {
                   "thread_id": thread.id,
                   "message": "",
                   "required_actions": []
            }
            data = json.loads(request.body)
            # Now check if any action is needed or client sent back any result of previous action
            tool_outputs = []
            run = client.beta.threads.runs.retrieve(
               thread_id=thread.id,
               run_id = data.get("run_id", ""))
            if not run:
                return JsonResponse({"error": "Run not found."}, status=404)
            #Check if client returned any result of previous action
            client_tool_result = data.get("tool_output", "")
            if client_tool_result:
                tool_outputs = tool_outputs_cache_mapping[thread.id]
                for output in client_tool_result:
                    tool_outputs.append(output)
                # Submit all tool outputs at once after collecting them in a list
            #curl -X POST -H "Content-Type: application/json" -d ‘{“tool_output”: [{“tool_call_id“ : “call_52v3rd3RWZOxUxhDlM6oG9sv”, “output”: “55”}]}’ http://127.0.0.1:8000/chat/
            submit_res = submit_tool_outputs( thread_id=thread.id,
                    run_id=run.id,
                    tool_outputs=tool_outputs)
            run = client.beta.threads.runs.retrieve(
               thread_id=thread.id,
               run_id = data.get("run_id", ""))
            while run.status != 'completed' and run.status != 'failed':
                    print(f"run status 2 is{run.status}")
                    if run.required_action != None:
                      shouldReturn = newActionRequired(run=run, response=response)
                      if shouldReturn:
                          return JsonResponse(response)
                    run = client.beta.threads.runs.retrieve(
                      thread_id=thread.id,
                      run_id = data.get("run_id", ""))    
            if run.status == 'completed':
                messages = client.beta.threads.messages.list(
                    thread_id=thread.id
                )
                response["message"] = messages.data[0].content[0].text.value
                print(messages.data[0])
            else:
                print(f"run status is: {run.status}")
            return JsonResponse(response)
           
    else:
        return JsonResponse({"error": "Invalid request method."}, status=400)


#Processes each 
def newActionRequired(run, response):
    tool_outputs = []
    # Loop through each tool in the required actionss
    need_client_action = False
    for tool in run.required_action.submit_tool_outputs.tool_calls:
        if tool.function.name == "search_recently_seen_objects":
            response["required_actions"].append({
                "tool_call_id": tool.id,
                "function_name": "search_recently_seen_objects",
                "arguments": tool.function.arguments
            })
          
            need_client_action = True
        elif tool.function.name == "navigate_user_to":
            response["required_actions"].append({
                "tool_call_id": tool.id,
                "function_name": "navigate_user_to",
                "arguments": tool.function.arguments
            })
            need_client_action = True    
        elif tool.function.name == "get_available_keywords":
            print(f"chatgpt asked for keywords, call id: {tool.id}")
            tool_outputs.append({
                "tool_call_id": tool.id,
                "output": COCO_CLASS_NAMES
            })

    if need_client_action:
        tool_outputs_cache_mapping[thread.id] = tool_outputs
        response["run_id"] = run.id
        return True
    
    # Submit the tool outputs
    if submit_tool_outputs(thread.id, run.id, tool_outputs):
        print("Submission handled successfully.")
    else:
        print("Submission failed or no tool outputs were present.")
    return False

def submit_tool_outputs(thread_id, run_id, tool_outputs):
    """
    Submits tool outputs and returns True if successful, False otherwise.
    """
    if not tool_outputs:
        print("No tool outputs to submit.")
        return False
    try:
        client.beta.threads.runs.submit_tool_outputs_and_poll(
            thread_id=thread_id,
            run_id=run_id,
            tool_outputs=tool_outputs
        )
        print("Tool outputs submitted successfully.")
        return True
    except Exception as e:
        print("Failed to submit tool outputs:", e)
        return False