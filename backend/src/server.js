import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { z } from "zod";
import OpenAI from "openai";

dotenv.config();

const app = express();
const PORT = process.env.PORT ? Number(process.env.PORT) : 3001;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini"; // Chat Completions-compatible model

if (!OPENAI_API_KEY) {
  console.warn(
    "[WARN] OPENAI_API_KEY not set. The API will return a heuristic template instead of LLM output."
  );
}

app.use(
  cors({
    origin: process.env.CORS_ORIGIN?.split(",").map((o) => o.trim()) || [
      "http://localhost:3000",
      "http://127.0.0.1:3000",
      "http://localhost:5173",
      "http://127.0.0.1:5173",
      "http://localhost:8080",
      "http://127.0.0.1:8080",
      "null", // allow file:// origins in some browsers
    ],
    credentials: false,
  })
);
app.use(express.json({ limit: "1mb" }));

const requestSchema = z.object({
  personName: z.string().min(1),
  recipientName: z.string().min(1),
  audience: z
    .string()
    .default("instructor"), // e.g., instructor, professor, manager, organizer
  context: z
    .string()
    .default("class"), // e.g., class, project submission, conference
  reason: z
    .string()
    .default("unexpected circumstances"), // e.g., illness, transportation delay, technical issues
  dateOrDeadline: z.string().optional(),
  tone: z
    .string()
    .default("professional and apologetic"), // e.g., apologetic, professional, concise, empathetic
  additionalDetails: z.string().optional(),
  askForExtension: z.boolean().optional().default(false),
  proposedNewDeadline: z.string().optional(),
  locale: z.string().optional().default("en"),
  length: z.string().optional().default("short"), // short | medium | long
});

const openai = OPENAI_API_KEY
  ? new OpenAI({ apiKey: OPENAI_API_KEY })
  : null;

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/generate", async (req, res) => {
  const parsed = requestSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: "Invalid request", details: parsed.error.flatten() });
  }
  const {
    personName,
    recipientName,
    audience,
    context,
    reason,
    dateOrDeadline,
    tone,
    additionalDetails,
    askForExtension,
    proposedNewDeadline,
    locale,
    length,
  } = parsed.data;

  // If no API key, return a simple template
  if (!openai) {
    const subject = `Apologies for being late (${context})`;
    const body = [
      `Dear ${recipientName},`,
      "",
      `I hope you are well. I wanted to sincerely apologize for being late ${
        context === "class" ? "to class" : context === "conference" ? "to the conference" : "with my submission"
      }. This was due to ${reason}.` + (dateOrDeadline ? ` The relevant date/deadline was ${dateOrDeadline}.` : ""),
      additionalDetails ? "" : "",
      additionalDetails || "",
      askForExtension && proposedNewDeadline
        ? `If possible, I would appreciate an extension until ${proposedNewDeadline}.`
        : "",
      "",
      "Thank you for your understanding.",
      "",
      `Best regards,`,
      personName,
    ]
      .filter(Boolean)
      .join("\n");
    return res.json({ subject, body, model: "template", usedLLM: false });
  }

  try {
    const sys = `You are an assistant that writes concise, professional emails explaining lateness with accountability and solutions. Always avoid implausible excuses. Adapt tone to the user's request and ensure it is culturally appropriate for the locale. Respond in JSON with {"subject": string, "body": string}.`;

    const instructions = {
      personName,
      recipientName,
      audience,
      context,
      reason,
      dateOrDeadline: dateOrDeadline || null,
      tone,
      additionalDetails: additionalDetails || null,
      askForExtension,
      proposedNewDeadline: proposedNewDeadline || null,
      locale,
      length,
    };

    const content = `Write an email explaining a late arrival/submission. Requirements:\n- Audience: ${audience}\n- Sender: ${personName}\n- Recipient: ${recipientName}\n- Context: ${context}\n- Reason: ${reason}\n- Date/Deadline: ${dateOrDeadline || "n/a"}\n- Tone: ${tone}\n- Locale: ${locale}\n- Length: ${length}\n- Additional details: ${additionalDetails || "n/a"}\n- Ask for extension: ${askForExtension ? `yes, propose ${proposedNewDeadline || "TBD"}` : "no"}\n\nConstraints:\n- Be sincere and accountable.\n- Offer a brief plan to avoid recurrence.\n- Keep subject line clear.\n- Return ONLY valid JSON with keys subject and body.`;

    const response = await openai.chat.completions.create({
      model: OPENAI_MODEL,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: sys },
        { role: "user", content },
      ],
      temperature: 0.7,
      max_tokens: 400,
    });

    const raw = response.choices?.[0]?.message?.content || "";
    let parsedJson;
    try {
      parsedJson = JSON.parse(raw);
    } catch (e) {
      // fallback: try to extract JSON
      const match = raw.match(/\{[\s\S]*\}/);
      parsedJson = match ? JSON.parse(match[0]) : null;
    }
    if (!parsedJson || typeof parsedJson.subject !== "string" || typeof parsedJson.body !== "string") {
      return res.status(502).json({ error: "Invalid model response", raw });
    }
    res.json({ subject: parsedJson.subject, body: parsedJson.body, model: OPENAI_MODEL, usedLLM: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Generation failed" });
  }
});

app.listen(PORT, () => {
  console.log(`Late email agent backend listening on http://localhost:${PORT}`);
});
