import os
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

try:
    from openai import OpenAI  # type: ignore
except Exception:  # pragma: no cover
    OpenAI = None  # type: ignore

class GenerateRequest(BaseModel):
    personName: str = Field(..., min_length=1)
    recipientName: str = Field(..., min_length=1)
    audience: str = "instructor"
    context: str = "class"  # class | project submission | conference
    reason: str = "unexpected circumstances"
    dateOrDeadline: Optional[str] = None
    tone: str = "professional and apologetic"
    additionalDetails: Optional[str] = None
    askForExtension: bool = False
    proposedNewDeadline: Optional[str] = None
    locale: str = "en"
    length: str = "short"  # short | medium | long

class SendEmailRequest(BaseModel):
    fromEmail: str
    fromName: str
    toEmail: str
    toName: Optional[str] = None
    subject: str
    bodyText: Optional[str] = None
    bodyHtml: Optional[str] = None

app = FastAPI(title="Agent Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"ok": True}

def _template_response(req: GenerateRequest):
    subject = f"Apologies for being late ({req.context})"
    what = (
        "to class"
        if req.context == "class"
        else ("to the conference" if req.context == "conference" else "with my submission")
    )
    parts = [
        f"Dear {req.recipientName},",
        "",
        f"I hope you are well. I wanted to sincerely apologize for being late {what}. This was due to {req.reason}."
        + (f" The relevant date/deadline was {req.dateOrDeadline}." if req.dateOrDeadline else ""),
        req.additionalDetails or "",
        f"If possible, I would appreciate an extension until {req.proposedNewDeadline}."
        if (req.askForExtension and req.proposedNewDeadline)
        else "",
        "",
        "I will make adjustments to prevent this from happening again.",
        "",
        "Thank you for your understanding.",
        "",
        "Best regards,",
        req.personName,
    ]
    body = "\n".join([p for p in parts if p])
    return {"subject": subject, "body": body, "model": "template", "usedLLM": False}

@app.post("/generate")
def generate(req: GenerateRequest):
    api_key = os.getenv("OPENAI_API_KEY")
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    if not api_key or OpenAI is None:
        return _template_response(req)

    client = OpenAI(api_key=api_key)

    system_msg = (
        "You are an assistant that writes concise, professional emails explaining lateness with "
        "accountability and solutions. Avoid implausible excuses. Adapt tone and locale. "
        "Respond in JSON with {\"subject\": string, \"body\": string}."
    )

    user_content = (
        "Write an email explaining a late arrival/submission. Requirements:\n"
        f"- Audience: {req.audience}\n"
        f"- Sender: {req.personName}\n"
        f"- Recipient: {req.recipientName}\n"
        f"- Context: {req.context}\n"
        f"- Reason: {req.reason}\n"
        f"- Date/Deadline: {req.dateOrDeadline or 'n/a'}\n"
        f"- Tone: {req.tone}\n"
        f"- Locale: {req.locale}\n"
        f"- Length: {req.length}\n"
        f"- Additional details: {req.additionalDetails or 'n/a'}\n"
        f"- Ask for extension: {'yes, propose ' + (req.proposedNewDeadline or 'TBD') if req.askForExtension else 'no'}\n\n"
        "Constraints:\n"
        "- Be sincere and accountable.\n"
        "- Offer a brief plan to avoid recurrence.\n"
        "- Keep subject line clear.\n"
        "- Return ONLY valid JSON with keys subject and body."
    )

    try:
        resp = client.chat.completions.create(
            model=model,
            response_format={"type": "json_object"},
            messages=[{"role": "system", "content": system_msg}, {"role": "user", "content": user_content}],
            temperature=0.7,
            max_tokens=400,
        )
        content = resp.choices[0].message.content or ""
    except Exception as e:  # pragma: no cover
        raise HTTPException(status_code=500, detail=f"Generation failed: {e}")

    import json

    try:
        data = json.loads(content)
    except Exception:
        # naive fallback: best-effort extraction
        import re

        m = re.search(r"\{[\s\S]*\}", content)
        if not m:
            raise HTTPException(status_code=502, detail="Invalid model response")
        data = json.loads(m.group(0))

    if not isinstance(data, dict) or "subject" not in data or "body" not in data:
        raise HTTPException(status_code=502, detail="Invalid model response structure")

    return {"subject": data["subject"], "body": data["body"], "model": model, "usedLLM": True}

@app.post("/send")
def send_email(req: SendEmailRequest):
    api_key = os.getenv("MAILERSEND_API_KEY")
    if not api_key:
        raise HTTPException(status_code=400, detail="MAILERSEND_API_KEY is not set")

    # Prefer SDK if available, otherwise use REST fallback
    try:
        from mailersend.emails import NewEmail, EmailParams  # type: ignore

        email = NewEmail(api_key=api_key)
        params = EmailParams()
        params.set_mail_from({"email": req.fromEmail, "name": req.fromName})
        params.set_subject(req.subject)
        params.set_to([{ "email": req.toEmail, "name": req.toName or req.toEmail }])
        if req.bodyText:
            params.set_text(req.bodyText)
        if req.bodyHtml:
            params.set_html(req.bodyHtml)
        result = email.send(params)
        status = getattr(result, "status_code", None) or getattr(result, "status", None) or 202
        if int(status) >= 300:
            raise HTTPException(status_code=502, detail=f"MailerSend send failed: {status}")
        return {"ok": True}
    except Exception:
        import requests

        payload = {
            "from": {"email": req.fromEmail, "name": req.fromName},
            "to": [{"email": req.toEmail, "name": req.toName or req.toEmail}],
            "subject": req.subject,
        }
        if req.bodyText:
            payload["text"] = req.bodyText
        if req.bodyHtml:
            payload["html"] = req.bodyHtml

        r = requests.post(
            "https://api.mailersend.com/v1/email",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=20,
        )
        if r.status_code >= 300:
            raise HTTPException(status_code=502, detail=f"MailerSend send failed: {r.status_code} {r.text}")
        return {"ok": True}

if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    port = int(os.getenv("PORT", "3001"))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)