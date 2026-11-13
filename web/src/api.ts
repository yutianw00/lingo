// Thin client for the FastAPI backend. Every request carries the user id
// (placeholder until SSO) and the browser's timezone offset (for "today"/streaks).

export type Lang = 'zh' | 'en' | 'fr' | 'es'
export type Level = 'new' | 'learning' | 'familiar' | 'mastered'

export interface Me {
  id: string
  native: Lang
  target: Lang
  onboarded: boolean
  daily_goal: number
}

export interface Progress {
  mastery: number
  level: Level
  due: number | null
  reps: number
  lapses: number
}

export type Gender = 'm' | 'f' | 'mf' | ''
export type Skill = 'vocab' | 'form' | 'context'

export interface WordCard extends Progress {
  id: string
  word: string
  pos: string
  gender: Gender
  difficulty: number
  difficulty_level: number
  topic: string
  meaning: string
  example: string
  example_translation: string
}

export interface Option {
  text: string
  translation: string | null
}

export interface Question extends Progress {
  id: string
  kind: 'fill' | 'next'
  skill: Skill
  difficulty_level: number
  prompt: string
  translation: string
  options: Option[]
}

export interface AnswerResult {
  correct: boolean
  answer: string
  full_sentence: string
  translation: string
  before: Progress
  after: Progress
}

export interface ReviewResult {
  grade: string
  before: Progress
  after: Progress
}

type Levels = Record<Level, number>
export interface Home {
  native: Lang
  target: Lang
  leveled: boolean
  level: number
  level_score: number
  streak: number
  today: { done: number; goal: number }
  words: { total: number; due: number; new: number; levels: Levels }
  quiz: { total: number; due: number; new: number; mistakes: number; levels: Levels }
}

function userId(): string {
  try {
    return localStorage.getItem('lingo.uid') || 'demo'
  } catch {
    return 'demo'
  }
}

async function req<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch('/api' + path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      'X-User-Id': userId(),
      'X-Tz-Offset': String(new Date().getTimezoneOffset()),
      ...init.headers,
    },
  })
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`)
  return res.json() as Promise<T>
}

const post = <T>(path: string, body?: unknown) =>
  req<T>(path, { method: 'POST', body: body === undefined ? undefined : JSON.stringify(body) })

export const api = {
  me: () => req<Me>('/me'),
  saveMe: (b: { native: Lang; target: Lang }) => req<Me>('/me', { method: 'PUT', body: JSON.stringify(b) }),
  home: () => req<Home>('/home'),
  wordSession: (size = 20) => req<WordCard[]>(`/words/session?size=${size}`),
  reviewWord: (id: string, b: { known: boolean; peeked: boolean; elapsed_ms: number }) =>
    post<ReviewResult>(`/words/${encodeURIComponent(id)}/review`, b),
  undoWord: (id: string) => post<Progress>(`/words/${encodeURIComponent(id)}/undo`),
  words: () => req<WordCard[]>('/words'),
  quizSession: (size = 10) => req<Question[]>(`/quiz/session?size=${size}`),
  answer: (id: string, b: { choice: string; elapsed_ms: number }) =>
    post<AnswerResult>(`/quiz/${encodeURIComponent(id)}/answer`, b),
}

const TTS: Record<Lang, string> = { zh: 'zh-CN', en: 'en-US', fr: 'fr-FR', es: 'es-ES' }

export function speak(text: string, lang: Lang) {
  try {
    speechSynthesis.cancel()
    const u = new SpeechSynthesisUtterance(text)
    u.lang = TTS[lang]
    u.rate = 0.9
    speechSynthesis.speak(u)
  } catch {
    /* TTS unavailable */
  }
}
