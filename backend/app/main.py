import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import FastAPI
from fastapi import HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="REHAB-X AI API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "rehab-x-ai"}


@app.get("/api/exercises")
def exercises() -> dict[str, list]:
    return {"exercises": []}


@app.post("/api/sessions")
def create_session() -> dict[str, str]:
    return {"status": "not_configured", "message": "Session backend persistence is not configured."}


@app.get("/api/sessions/{athlete_id}")
def sessions(athlete_id: str) -> dict[str, object]:
    return {"athlete_id": athlete_id, "sessions": []}


@app.get("/api/progress/{athlete_id}")
def progress(athlete_id: str) -> dict[str, object]:
    return {"athlete_id": athlete_id, "status": "insufficient_data", "trend": []}


class AiChatRequest(BaseModel):
    question: str
    context: dict[str, object] = {}


@app.get("/api/ai/status")
def ai_status() -> dict[str, object]:
    return {
        "configured": bool(os.getenv("GEMINI_API_KEY")),
        "provider": "gemini",
        "model": os.getenv("GEMINI_MODEL", "gemini-2.5-flash"),
    }


@app.post("/api/ai/chat")
def ai_chat(request: AiChatRequest) -> dict[str, object]:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="GEMINI_API_KEY is not configured on the backend.")

    model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    prompt = _coach_prompt(request.context)
    payload = {
        "systemInstruction": {"parts": [{"text": prompt}]},
        "contents": _conversation_contents(request.question, request.context),
        "generationConfig": {
            "temperature": 0.55,
            "responseMimeType": "application/json",
        },
    }
    endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    outbound = Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        method="POST",
    )

    try:
        with urlopen(outbound, timeout=30) as response:
            provider_payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise HTTPException(status_code=502, detail=f"Gemini request failed: {detail[:500]}") from error
    except (URLError, TimeoutError) as error:
        raise HTTPException(status_code=502, detail="Gemini could not be reached.") from error

    try:
        text = provider_payload["candidates"][0]["content"]["parts"][0]["text"]
        return _response_from_model(text)
    except (KeyError, IndexError, TypeError, json.JSONDecodeError) as error:
        raise HTTPException(status_code=502, detail="Gemini returned an invalid coach response.") from error


def _coach_prompt(context: dict[str, object]) -> str:
    context_without_history = dict(context)
    context_without_history.pop("conversationHistory", None)
    context_json = json.dumps(context_without_history, ensure_ascii=True)
    return f"""You are Mitra, REHAB-X AI's helpful, conversational assistant.
Answer the athlete's actual question directly and naturally, like a capable general-purpose
chat assistant. You may answer general questions about exercise, movement, recovery, nutrition
basics, and everyday topics; do not force every answer into a movement-analysis template.
Use the supplied profile and movement data only when relevant. Never invent measurements or
claim to have observed data that is not provided. If a personal measurement is missing, say so.
When a response language is provided in context, answer in that language. Do not diagnose medical
conditions, prescribe medication, or claim medical clearance. For pain,
injury, or urgent symptoms, give cautious general information and recommend an appropriate
licensed healthcare professional. Match the athlete's language and keep the answer useful and
clear, using detail appropriate to the question.
Return valid JSON with these string/list fields. Put the complete conversational answer in
summary; use the other fields only for relevant observations and concise optional guidance:
summary, observations, trainingSuggestions, professionalReviewQuestions, limitations,
evidenceUsed, basedOn.

Verified app context (not a restriction on general questions):
{context_json}
"""


def _conversation_contents(
    question: str, context: dict[str, object]
) -> list[dict[str, object]]:
    history = context.get("conversationHistory", [])
    turns: list[dict[str, object]] = []
    if isinstance(history, list):
        for item in history:
            if not isinstance(item, dict):
                continue
            role = item.get("role")
            content = item.get("content")
            if role not in ("user", "assistant") or not isinstance(content, str):
                continue
            content = content.strip()[:4000]
            if content:
                turns.append(
                    {
                        "role": "model" if role == "assistant" else "user",
                        "parts": [{"text": content}],
                    }
                )

    turns = turns[-12:]
    while turns and turns[0]["role"] == "model":
        turns.pop(0)
    latest_text = turns[-1]["parts"][0]["text"] if turns else None
    if not turns or turns[-1]["role"] != "user" or latest_text != question:
        turns.append({"role": "user", "parts": [{"text": question[:4000]}]})
    return turns


def _response_from_model(text: str) -> dict[str, object]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    parsed = json.loads(cleaned)
    required_lists = (
        "observations",
        "trainingSuggestions",
        "professionalReviewQuestions",
        "limitations",
        "evidenceUsed",
    )
    if not isinstance(parsed, dict) or not isinstance(parsed.get("summary"), str):
        raise ValueError("Missing response summary")
    for field in required_lists:
        if not isinstance(parsed.get(field), list):
            parsed[field] = []
    parsed["isDemo"] = False
    parsed["basedOn"] = str(parsed.get("basedOn") or "Gemini analysis of supplied movement telemetry")
    return parsed