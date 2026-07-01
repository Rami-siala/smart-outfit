import os
from dotenv import load_dotenv
from google import genai

load_dotenv()

API_KEY = os.getenv("GEMINI_API_KEY")
print(f"Key loaded: {API_KEY[:10]}..." if API_KEY else "❌ No key found!")

try:
    client = genai.Client(api_key=API_KEY)
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents="Say hello in one word",
    )
    print("✅ Gemini API works!")
    print("Response:", response.text)
except Exception as e:
    print("❌ Failed:", e)