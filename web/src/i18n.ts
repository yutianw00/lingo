// UI strings. The interface is always shown in the learner's native language.
import type { Lang, Level } from './api'

export interface Strings {
  langName: Record<Lang, string>
  pos: Record<string, string>
  level: Record<Level, string>
  gender: Record<'m' | 'f' | 'mf', string>
  skill: Record<'vocab' | 'form' | 'context', string>
  vocabHint: string
  formHint: string
  quizLocked: string
  goSwipe: string
  lv: (n: number) => string
  showMore: (n: number) => string
  signInSubtitle: string
  signInGoogle: string
  signInError: Record<'cancelled' | 'state' | 'failed', string>
  account: string
  signOut: string
  getStarted: string
  myLanguage: string
  iWantToLearn: string
  learningPair: (native: string, target: string) => string
  start: string
  save: string
  loading: string
  error: string
  retry: string
  // home
  dailyGoal: (n: number) => string
  remaining: (n: number) => string
  goalDone: string
  streakDays: (n: number) => string
  practice: string
  swipeTitle: string
  swipeDesc: string
  due: (n: number) => string
  newCount: (n: number) => string
  quizTitle: string
  quizDesc: string
  mistakes: (n: number) => string
  perRound: (n: number) => string
  vocab: string
  quizProgress: string
  total: (n: number) => string
  tabLearn: string
  tabWords: string
  // swipe
  tapToReveal: string
  known: string
  unknown: string
  undo: string
  undone: string
  roundDone: string
  roundHint: string
  goQuiz: string
  again: string
  // quiz
  fill: string
  next: string
  fillHint: string
  nextHint: string
  showTranslation: string
  check: string
  correct: string
  correctAnswer: string
  continue: string
  yourChoice: string
  tapWordHint: string
  addWord: string
  wordAdded: string
  noGloss: string
  custom: string
  removeWord: (w: string) => string
  quizDone: string
  accuracy: (n: number) => string
  quizDoneHint: string
  backHome: string
  // words
  wordsTitle: string
  search: string
  all: string
  dueNow: string
  inHours: (n: number) => string
  inDays: (n: number) => string
  notLearned: string
  noMatch: string
}

const zh: Strings = {
  langName: { zh: '简体中文', en: '英语', fr: '法语', es: '西班牙语' },
  pos: { n: '名词', v: '动词', adj: '形容词', adv: '副词', pron: '代词', prep: '介词', conj: '连词', num: '数词', interj: '叹词', phr: '短语', det: '限定词', name: '专有名词', part: '助词' },
  level: { new: '新词', learning: '学习中', familiar: '熟悉', mastered: '已掌握' },
  gender: { m: '阳性', f: '阴性', mf: '阴阳同形' },
  skill: { vocab: '单词填空', form: '词形变化', context: '情景对话' },
  vocabHint: '选出句子里缺的词',
  formHint: '选出正确的形式',
  quizLocked: '先去刷几个单词，选择题会随着你的词汇解锁',
  goSwipe: '去刷单词',
  lv: (n) => `Lv ${n}`,
  showMore: (n) => `再显示 ${Math.min(n, 150)} 个（剩余 ${n}）`,
  signInSubtitle: '刷单词、做选择题，每天进步一点',
  signInGoogle: '使用 Google 登录',
  signInError: { cancelled: '登录已取消', state: '登录已过期，请重试', failed: '登录失败，请重试' },
  account: '账户',
  signOut: '退出登录',
  getStarted: '开始学习',
  myLanguage: '我的母语',
  iWantToLearn: '我想学',
  learningPair: (n, t) => `用${n}学${t}`,
  start: '开始',
  save: '保存',
  loading: '加载中…',
  error: '出错了，请检查后端是否在运行',
  retry: '重试',
  dailyGoal: (n) => `今日目标 ${n} 次练习`,
  remaining: (n) => `还差 ${n} 次，保持连胜！`,
  goalDone: '今日目标完成 🎉',
  streakDays: (n) => `${n} 天`,
  practice: '练习',
  swipeTitle: '单词快刷',
  swipeDesc: '右滑认识，左滑不认识，点卡片看释义',
  due: (n) => `待复习 ${n}`,
  newCount: (n) => `新词 ${n}`,
  quizTitle: '选择题',
  quizDesc: '选词填空 · 接下句',
  mistakes: (n) => `错题待复习 ${n}`,
  perRound: (n) => `${n} 题 / 组`,
  vocab: '词汇熟练度',
  quizProgress: '题目熟练度',
  total: (n) => `共 ${n}`,
  tabLearn: '学习',
  tabWords: '词库',
  tapToReveal: '点一下查看释义',
  known: '认识',
  unknown: '不认识',
  undo: '撤销',
  undone: '已撤销',
  roundDone: '本轮完成！',
  roundHint: '不认识的词几小时后会再出现',
  goQuiz: '去做选择题',
  again: '再刷一轮',
  fill: '选词填空',
  next: '接下句',
  fillHint: '选择正确的词补全句子',
  nextHint: '选择最自然的下一句',
  showTranslation: '显示翻译',
  check: '检查',
  correct: '太棒了！',
  correctAnswer: '正确答案：',
  continue: '继续',
  yourChoice: '你的选择',
  tapWordHint: '点句子里的单词可查看释义',
  addWord: '加入我的单词',
  wordAdded: '已加入 ✓',
  noGloss: '暂无释义',
  custom: '自定义',
  removeWord: (w) => `从我的单词中删除“${w}”？`,
  quizDone: '练习完成',
  accuracy: (n) => `正确率 ${n}%`,
  quizDoneHint: '答错的题会更快再出现',
  backHome: '返回首页',
  wordsTitle: '词库',
  search: '搜索单词或释义',
  all: '全部',
  dueNow: '待复习',
  inHours: (n) => `${n} 小时后`,
  inDays: (n) => `${n} 天后`,
  notLearned: '未学',
  noMatch: '没有匹配的词',
}

const en: Strings = {
  langName: { zh: 'Chinese', en: 'English', fr: 'French', es: 'Spanish' },
  pos: { n: 'noun', v: 'verb', adj: 'adj.', adv: 'adv.', pron: 'pron.', prep: 'prep.', conj: 'conj.', num: 'number', interj: 'interj.', phr: 'phrase', det: 'det.', name: 'name', part: 'particle' },
  level: { new: 'New', learning: 'Learning', familiar: 'Familiar', mastered: 'Mastered' },
  gender: { m: 'masculine', f: 'feminine', mf: 'm/f' },
  skill: { vocab: 'Vocabulary', form: 'Word forms', context: 'Conversation' },
  vocabHint: 'Pick the missing word',
  formHint: 'Pick the correct form',
  quizLocked: 'Swipe some words first — questions unlock as your vocabulary grows',
  goSwipe: 'Swipe words',
  lv: (n) => `Lv ${n}`,
  showMore: (n) => `Show more (${n} left)`,
  signInSubtitle: 'Swipe words, answer questions, get a little better every day',
  signInGoogle: 'Sign in with Google',
  signInError: { cancelled: 'Sign-in was cancelled', state: 'Sign-in expired, please try again', failed: 'Sign-in failed, please try again' },
  account: 'Account',
  signOut: 'Sign out',
  getStarted: 'Get started',
  myLanguage: 'I speak',
  iWantToLearn: 'I want to learn',
  learningPair: (n, t) => `Learning ${t} from ${n}`,
  start: 'Start',
  save: 'Save',
  loading: 'Loading…',
  error: 'Something went wrong — is the backend running?',
  retry: 'Retry',
  dailyGoal: (n) => `Daily goal: ${n} reviews`,
  remaining: (n) => `${n} to go — keep your streak!`,
  goalDone: 'Daily goal reached 🎉',
  streakDays: (n) => `${n} day${n === 1 ? '' : 's'}`,
  practice: 'Practice',
  swipeTitle: 'Word swipe',
  swipeDesc: 'Swipe right if you know it, left if not, tap for the meaning',
  due: (n) => `${n} due`,
  newCount: (n) => `${n} new`,
  quizTitle: 'Multiple choice',
  quizDesc: 'Fill the blank · What comes next',
  mistakes: (n) => `${n} mistakes to review`,
  perRound: (n) => `${n} per round`,
  vocab: 'Vocabulary',
  quizProgress: 'Questions',
  total: (n) => `${n} total`,
  tabLearn: 'Learn',
  tabWords: 'Words',
  tapToReveal: 'Tap to see the meaning',
  known: 'Know it',
  unknown: "Don't know",
  undo: 'Undo',
  undone: 'Undone',
  roundDone: 'Round complete!',
  roundHint: "Words you didn't know will come back in a few hours",
  goQuiz: 'Practice with questions',
  again: 'Another round',
  fill: 'Fill the blank',
  next: 'What comes next',
  fillHint: 'Pick the word that completes the sentence',
  nextHint: 'Pick the most natural reply',
  showTranslation: 'Show translation',
  check: 'Check',
  correct: 'Great job!',
  correctAnswer: 'Correct answer: ',
  continue: 'Continue',
  yourChoice: 'Your choice',
  tapWordHint: 'Tap any word to see what it means',
  addWord: 'Add to my words',
  wordAdded: 'Added ✓',
  noGloss: 'No translation available',
  custom: 'Custom',
  removeWord: (w) => `Remove “${w}” from your words?`,
  quizDone: 'Practice complete',
  accuracy: (n) => `${n}% correct`,
  quizDoneHint: 'Questions you missed will come back sooner',
  backHome: 'Back to home',
  wordsTitle: 'Words',
  search: 'Search words or meanings',
  all: 'All',
  dueNow: 'Due',
  inHours: (n) => `in ${n}h`,
  inDays: (n) => `in ${n}d`,
  notLearned: 'not started',
  noMatch: 'No matching words',
}

const fr: Strings = {
  langName: { zh: 'chinois', en: 'anglais', fr: 'français', es: 'espagnol' },
  pos: { n: 'nom', v: 'verbe', adj: 'adj.', adv: 'adv.', pron: 'pron.', prep: 'prép.', conj: 'conj.', num: 'nombre', interj: 'interj.', phr: 'expression', det: 'dét.', name: 'nom propre', part: 'particule' },
  level: { new: 'Nouveau', learning: 'En cours', familiar: 'Connu', mastered: 'Maîtrisé' },
  gender: { m: 'masculin', f: 'féminin', mf: 'm/f' },
  skill: { vocab: 'Vocabulaire', form: 'Formes', context: 'Dialogue' },
  vocabHint: 'Choisis le mot manquant',
  formHint: 'Choisis la bonne forme',
  quizLocked: "Révise d'abord quelques mots : les questions se débloquent avec ton vocabulaire",
  goSwipe: 'Réviser des mots',
  lv: (n) => `Niv. ${n}`,
  showMore: (n) => `Afficher plus (${n} restants)`,
  signInSubtitle: 'Des mots, des questions, un petit progrès chaque jour',
  signInGoogle: 'Se connecter avec Google',
  signInError: { cancelled: 'Connexion annulée', state: 'Connexion expirée, réessaie', failed: 'Échec de la connexion, réessaie' },
  account: 'Compte',
  signOut: 'Se déconnecter',
  getStarted: 'Commencer',
  myLanguage: 'Je parle',
  iWantToLearn: "Je veux apprendre",
  learningPair: (n, t) => `${n} → ${t}`,
  start: 'Commencer',
  save: 'Enregistrer',
  loading: 'Chargement…',
  error: 'Une erreur est survenue — le serveur est-il lancé ?',
  retry: 'Réessayer',
  dailyGoal: (n) => `Objectif du jour : ${n} révisions`,
  remaining: (n) => `Encore ${n} — garde ta série !`,
  goalDone: 'Objectif du jour atteint 🎉',
  streakDays: (n) => `${n} j`,
  practice: 'Entraînement',
  swipeTitle: 'Mots express',
  swipeDesc: 'À droite si tu connais, à gauche sinon, touche pour le sens',
  due: (n) => `${n} à revoir`,
  newCount: (n) => `${n} nouveaux`,
  quizTitle: 'QCM',
  quizDesc: 'Texte à trous · Et ensuite ?',
  mistakes: (n) => `${n} erreurs à revoir`,
  perRound: (n) => `${n} par série`,
  vocab: 'Vocabulaire',
  quizProgress: 'Questions',
  total: (n) => `${n} au total`,
  tabLearn: 'Apprendre',
  tabWords: 'Mots',
  tapToReveal: 'Touche pour voir le sens',
  known: 'Je connais',
  unknown: 'Je ne sais pas',
  undo: 'Annuler',
  undone: 'Annulé',
  roundDone: 'Série terminée !',
  roundHint: 'Les mots inconnus reviendront dans quelques heures',
  goQuiz: 'Passer au QCM',
  again: 'Encore une série',
  fill: 'Texte à trous',
  next: 'Et ensuite ?',
  fillHint: 'Choisis le mot qui complète la phrase',
  nextHint: 'Choisis la suite la plus naturelle',
  showTranslation: 'Voir la traduction',
  check: 'Vérifier',
  correct: 'Bravo !',
  correctAnswer: 'Bonne réponse : ',
  continue: 'Continuer',
  yourChoice: 'Votre choix',
  tapWordHint: 'Touchez un mot pour voir sa traduction',
  addWord: 'Ajouter à mes mots',
  wordAdded: 'Ajouté ✓',
  noGloss: 'Pas de traduction disponible',
  custom: 'Perso',
  removeWord: (w) => `Retirer « ${w} » de vos mots ?`,
  quizDone: 'Entraînement terminé',
  accuracy: (n) => `${n} % de bonnes réponses`,
  quizDoneHint: 'Les questions ratées reviendront plus vite',
  backHome: "Retour à l'accueil",
  wordsTitle: 'Mots',
  search: 'Chercher un mot ou un sens',
  all: 'Tous',
  dueNow: 'À revoir',
  inHours: (n) => `dans ${n} h`,
  inDays: (n) => `dans ${n} j`,
  notLearned: 'pas commencé',
  noMatch: 'Aucun mot trouvé',
}

const es: Strings = {
  langName: { zh: 'chino', en: 'inglés', fr: 'francés', es: 'español' },
  pos: { n: 'sust.', v: 'verbo', adj: 'adj.', adv: 'adv.', pron: 'pron.', prep: 'prep.', conj: 'conj.', num: 'número', interj: 'interj.', phr: 'expresión', det: 'det.', name: 'nombre propio', part: 'partícula' },
  level: { new: 'Nueva', learning: 'Aprendiendo', familiar: 'Conocida', mastered: 'Dominada' },
  gender: { m: 'masculino', f: 'femenino', mf: 'm/f' },
  skill: { vocab: 'Vocabulario', form: 'Formas', context: 'Diálogo' },
  vocabHint: 'Elige la palabra que falta',
  formHint: 'Elige la forma correcta',
  quizLocked: 'Primero repasa algunas palabras: las preguntas se desbloquean con tu vocabulario',
  goSwipe: 'Repasar palabras',
  lv: (n) => `Nv. ${n}`,
  showMore: (n) => `Mostrar más (quedan ${n})`,
  signInSubtitle: 'Palabras, preguntas y un poco de progreso cada día',
  signInGoogle: 'Iniciar sesión con Google',
  signInError: { cancelled: 'Inicio de sesión cancelado', state: 'La sesión caducó, inténtalo de nuevo', failed: 'No se pudo iniciar sesión, inténtalo de nuevo' },
  account: 'Cuenta',
  signOut: 'Cerrar sesión',
  getStarted: 'Empezar',
  myLanguage: 'Hablo',
  iWantToLearn: 'Quiero aprender',
  learningPair: (n, t) => `Aprender ${t} desde ${n}`,
  start: 'Empezar',
  save: 'Guardar',
  loading: 'Cargando…',
  error: 'Algo salió mal: ¿está funcionando el servidor?',
  retry: 'Reintentar',
  dailyGoal: (n) => `Meta diaria: ${n} repasos`,
  remaining: (n) => `Faltan ${n}: ¡mantén tu racha!`,
  goalDone: 'Meta diaria cumplida 🎉',
  streakDays: (n) => `${n} d`,
  practice: 'Práctica',
  swipeTitle: 'Palabras rápidas',
  swipeDesc: 'Desliza a la derecha si la sabes, a la izquierda si no; toca para ver el significado',
  due: (n) => `${n} por repasar`,
  newCount: (n) => `${n} nuevas`,
  quizTitle: 'Opción múltiple',
  quizDesc: 'Completa la frase · ¿Qué sigue?',
  mistakes: (n) => `${n} errores por repasar`,
  perRound: (n) => `${n} por ronda`,
  vocab: 'Vocabulario',
  quizProgress: 'Preguntas',
  total: (n) => `${n} en total`,
  tabLearn: 'Aprender',
  tabWords: 'Palabras',
  tapToReveal: 'Toca para ver el significado',
  known: 'La sé',
  unknown: 'No la sé',
  undo: 'Deshacer',
  undone: 'Deshecho',
  roundDone: '¡Ronda completada!',
  roundHint: 'Las palabras que no sabías volverán en unas horas',
  goQuiz: 'Practicar con preguntas',
  again: 'Otra ronda',
  fill: 'Completa la frase',
  next: '¿Qué sigue?',
  fillHint: 'Elige la palabra que completa la frase',
  nextHint: 'Elige la respuesta más natural',
  showTranslation: 'Ver traducción',
  check: 'Comprobar',
  correct: '¡Muy bien!',
  correctAnswer: 'Respuesta correcta: ',
  continue: 'Continuar',
  yourChoice: 'Tu elección',
  tapWordHint: 'Toca una palabra para ver qué significa',
  addWord: 'Añadir a mis palabras',
  wordAdded: 'Añadida ✓',
  noGloss: 'No hay traducción',
  custom: 'Personal',
  removeWord: (w) => `¿Quitar «${w}» de tus palabras?`,
  quizDone: 'Práctica completada',
  accuracy: (n) => `${n} % de aciertos`,
  quizDoneHint: 'Las preguntas falladas volverán antes',
  backHome: 'Volver al inicio',
  wordsTitle: 'Palabras',
  search: 'Buscar palabras o significados',
  all: 'Todas',
  dueNow: 'Por repasar',
  inHours: (n) => `en ${n} h`,
  inDays: (n) => `en ${n} d`,
  notLearned: 'sin empezar',
  noMatch: 'No hay palabras',
}

export const STRINGS: Record<Lang, Strings> = { zh, en, fr, es }
export const LANGS: Lang[] = ['zh', 'en', 'fr', 'es']
export const SELF_NAME: Record<Lang, string> = { zh: '简体中文', en: 'English', fr: 'Français', es: 'Español' }

/** Best guess at the visitor's language before they sign in. */
export function browserLang(): Lang {
  const l = (navigator.language || 'en').slice(0, 2)
  return (LANGS as string[]).includes(l) ? (l as Lang) : 'en'
}
