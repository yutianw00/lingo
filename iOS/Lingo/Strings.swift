import Foundation

/// UI strings, ported from web/src/i18n.ts. The interface is shown in the learner's native language.
struct Strings {
    var langName: [Lang: String]
    var pos: [String: String]
    var level: [Level: String]
    var gender: [Gender: String]
    var skill: [Skill: String]
    var vocabHint: String
    var formHint: String
    var quizLocked: String
    var goSwipe: String
    var lv: (Int) -> String
    var signInSubtitle: String
    var signInGoogle: String
    var signInError: [String: String]
    var account: String
    var signOut: String
    var getStarted: String
    var myLanguage: String
    var iWantToLearn: String
    var learningPair: (String, String) -> String
    var start: String
    var save: String
    var loading: String
    var error: String
    var retry: String
    var dailyGoal: (Int) -> String
    var remaining: (Int) -> String
    var goalDone: String
    var streakDays: (Int) -> String
    var practice: String
    var swipeTitle: String
    var swipeDesc: String
    var due: (Int) -> String
    var newCount: (Int) -> String
    var quizTitle: String
    var quizDesc: String
    var mistakes: (Int) -> String
    var perRound: (Int) -> String
    var vocab: String
    var quizProgress: String
    var total: (Int) -> String
    var tabLearn: String
    var tabWords: String
    var tapToReveal: String
    var known: String
    var unknown: String
    var undo: String
    var undone: String
    var roundDone: String
    var roundHint: String
    var goQuiz: String
    var again: String
    var fill: String
    var next: String
    var fillHint: String
    var nextHint: String
    var showTranslation: String
    var check: String
    var correct: String
    var correctAnswer: String
    var `continue`: String
    var yourChoice: String
    var tapWordHint: String
    var addWord: String
    var wordAdded: String
    var noGloss: String
    var custom: String
    var remove: String
    var quizDone: String
    var accuracy: (Int) -> String
    var quizDoneHint: String
    var backHome: String
    var wordsTitle: String
    var search: String
    var all: String
    var dueNow: String
    var inHours: (Int) -> String
    var inDays: (Int) -> String
    var notLearned: String
    var noMatch: String
    var server: String

    static func `for`(_ lang: Lang) -> Strings {
        switch lang {
        case .zh: zh
        case .en: en
        case .fr: fr
        case .es: es
        }
    }

    static let zh = Strings(
        langName: [.zh: "简体中文", .en: "英语", .fr: "法语", .es: "西班牙语"],
        pos: ["n": "名词", "v": "动词", "adj": "形容词", "adv": "副词", "pron": "代词", "prep": "介词", "conj": "连词", "num": "数词", "interj": "叹词", "phr": "短语", "det": "限定词", "name": "专有名词", "part": "助词"],
        level: [.new: "新词", .learning: "学习中", .familiar: "熟悉", .mastered: "已掌握"],
        gender: [.m: "阳性", .f: "阴性", .mf: "阴阳同形"],
        skill: [.vocab: "单词填空", .form: "词形变化", .context: "情景对话"],
        vocabHint: "选出句子里缺的词",
        formHint: "选出正确的形式",
        quizLocked: "先去刷几个单词，选择题会随着你的词汇解锁",
        goSwipe: "去刷单词",
        lv: { "Lv \($0)" },
        signInSubtitle: "刷单词、做选择题，每天进步一点",
        signInGoogle: "使用 Google 登录",
        signInError: ["cancelled": "登录已取消", "state": "登录已过期，请重试", "failed": "登录失败，请重试"],
        account: "账户",
        signOut: "退出登录",
        getStarted: "开始学习",
        myLanguage: "我的母语",
        iWantToLearn: "我想学",
        learningPair: { "用\($0)学\($1)" },
        start: "开始",
        save: "保存",
        loading: "加载中…",
        error: "出错了，请检查后端是否在运行",
        retry: "重试",
        dailyGoal: { "今日目标 \($0) 次练习" },
        remaining: { "还差 \($0) 次，保持连胜！" },
        goalDone: "今日目标完成 🎉",
        streakDays: { "\($0) 天" },
        practice: "练习",
        swipeTitle: "单词快刷",
        swipeDesc: "右滑认识，左滑不认识，点卡片看释义",
        due: { "待复习 \($0)" },
        newCount: { "新词 \($0)" },
        quizTitle: "选择题",
        quizDesc: "选词填空 · 接下句",
        mistakes: { "错题待复习 \($0)" },
        perRound: { "\($0) 题 / 组" },
        vocab: "词汇熟练度",
        quizProgress: "题目熟练度",
        total: { "共 \($0)" },
        tabLearn: "学习",
        tabWords: "词库",
        tapToReveal: "点一下查看释义",
        known: "认识",
        unknown: "不认识",
        undo: "撤销",
        undone: "已撤销",
        roundDone: "本轮完成！",
        roundHint: "不认识的词几小时后会再出现",
        goQuiz: "去做选择题",
        again: "再刷一轮",
        fill: "选词填空",
        next: "接下句",
        fillHint: "选择正确的词补全句子",
        nextHint: "选择最自然的下一句",
        showTranslation: "显示翻译",
        check: "检查",
        correct: "太棒了！",
        correctAnswer: "正确答案：",
        continue: "继续",
        yourChoice: "你的选择",
        tapWordHint: "点句子里的单词可查看释义",
        addWord: "加入我的单词",
        wordAdded: "已加入 ✓",
        noGloss: "暂无释义",
        custom: "自定义",
        remove: "删除",
        quizDone: "练习完成",
        accuracy: { "正确率 \($0)%" },
        quizDoneHint: "答错的题会更快再出现",
        backHome: "返回首页",
        wordsTitle: "词库",
        search: "搜索单词或释义",
        all: "全部",
        dueNow: "待复习",
        inHours: { "\($0) 小时后" },
        inDays: { "\($0) 天后" },
        notLearned: "未学",
        noMatch: "没有匹配的词",
        server: "服务器地址"
    )

    static let en = Strings(
        langName: [.zh: "Chinese", .en: "English", .fr: "French", .es: "Spanish"],
        pos: ["n": "noun", "v": "verb", "adj": "adj.", "adv": "adv.", "pron": "pron.", "prep": "prep.", "conj": "conj.", "num": "number", "interj": "interj.", "phr": "phrase", "det": "det.", "name": "name", "part": "particle"],
        level: [.new: "New", .learning: "Learning", .familiar: "Familiar", .mastered: "Mastered"],
        gender: [.m: "masculine", .f: "feminine", .mf: "m/f"],
        skill: [.vocab: "Vocabulary", .form: "Word forms", .context: "Conversation"],
        vocabHint: "Pick the missing word",
        formHint: "Pick the correct form",
        quizLocked: "Swipe some words first — questions unlock as your vocabulary grows",
        goSwipe: "Swipe words",
        lv: { "Lv \($0)" },
        signInSubtitle: "Swipe words, answer questions, get a little better every day",
        signInGoogle: "Sign in with Google",
        signInError: ["cancelled": "Sign-in was cancelled", "state": "Sign-in expired, please try again", "failed": "Sign-in failed, please try again"],
        account: "Account",
        signOut: "Sign out",
        getStarted: "Get started",
        myLanguage: "I speak",
        iWantToLearn: "I want to learn",
        learningPair: { "Learning \($1) from \($0)" },
        start: "Start",
        save: "Save",
        loading: "Loading…",
        error: "Something went wrong — is the backend running?",
        retry: "Retry",
        dailyGoal: { "Daily goal: \($0) reviews" },
        remaining: { "\($0) to go — keep your streak!" },
        goalDone: "Daily goal reached 🎉",
        streakDays: { "\($0) day\($0 == 1 ? "" : "s")" },
        practice: "Practice",
        swipeTitle: "Word swipe",
        swipeDesc: "Swipe right if you know it, left if not, tap for the meaning",
        due: { "\($0) due" },
        newCount: { "\($0) new" },
        quizTitle: "Multiple choice",
        quizDesc: "Fill the blank · What comes next",
        mistakes: { "\($0) mistakes to review" },
        perRound: { "\($0) per round" },
        vocab: "Vocabulary",
        quizProgress: "Questions",
        total: { "\($0) total" },
        tabLearn: "Learn",
        tabWords: "Words",
        tapToReveal: "Tap to see the meaning",
        known: "Know it",
        unknown: "Don't know",
        undo: "Undo",
        undone: "Undone",
        roundDone: "Round complete!",
        roundHint: "Words you didn't know will come back in a few hours",
        goQuiz: "Practice with questions",
        again: "Another round",
        fill: "Fill the blank",
        next: "What comes next",
        fillHint: "Pick the word that completes the sentence",
        nextHint: "Pick the most natural reply",
        showTranslation: "Show translation",
        check: "Check",
        correct: "Great job!",
        correctAnswer: "Correct answer: ",
        continue: "Continue",
        yourChoice: "Your choice",
        tapWordHint: "Tap any word to see what it means",
        addWord: "Add to my words",
        wordAdded: "Added ✓",
        noGloss: "No translation available",
        custom: "Custom",
        remove: "Remove",
        quizDone: "Practice complete",
        accuracy: { "\($0)% correct" },
        quizDoneHint: "Questions you missed will come back sooner",
        backHome: "Back to home",
        wordsTitle: "Words",
        search: "Search words or meanings",
        all: "All",
        dueNow: "Due",
        inHours: { "in \($0)h" },
        inDays: { "in \($0)d" },
        notLearned: "not started",
        noMatch: "No matching words",
        server: "Server"
    )

    static let fr = Strings(
        langName: [.zh: "chinois", .en: "anglais", .fr: "français", .es: "espagnol"],
        pos: ["n": "nom", "v": "verbe", "adj": "adj.", "adv": "adv.", "pron": "pron.", "prep": "prép.", "conj": "conj.", "num": "nombre", "interj": "interj.", "phr": "expression", "det": "dét.", "name": "nom propre", "part": "particule"],
        level: [.new: "Nouveau", .learning: "En cours", .familiar: "Connu", .mastered: "Maîtrisé"],
        gender: [.m: "masculin", .f: "féminin", .mf: "m/f"],
        skill: [.vocab: "Vocabulaire", .form: "Formes", .context: "Dialogue"],
        vocabHint: "Choisis le mot manquant",
        formHint: "Choisis la bonne forme",
        quizLocked: "Révise d'abord quelques mots : les questions se débloquent avec ton vocabulaire",
        goSwipe: "Réviser des mots",
        lv: { "Niv. \($0)" },
        signInSubtitle: "Des mots, des questions, un petit progrès chaque jour",
        signInGoogle: "Se connecter avec Google",
        signInError: ["cancelled": "Connexion annulée", "state": "Connexion expirée, réessaie", "failed": "Échec de la connexion, réessaie"],
        account: "Compte",
        signOut: "Se déconnecter",
        getStarted: "Commencer",
        myLanguage: "Je parle",
        iWantToLearn: "Je veux apprendre",
        learningPair: { "\($0) → \($1)" },
        start: "Commencer",
        save: "Enregistrer",
        loading: "Chargement…",
        error: "Une erreur est survenue — le serveur est-il lancé ?",
        retry: "Réessayer",
        dailyGoal: { "Objectif du jour : \($0) révisions" },
        remaining: { "Encore \($0) — garde ta série !" },
        goalDone: "Objectif du jour atteint 🎉",
        streakDays: { "\($0) j" },
        practice: "Entraînement",
        swipeTitle: "Mots express",
        swipeDesc: "À droite si tu connais, à gauche sinon, touche pour le sens",
        due: { "\($0) à revoir" },
        newCount: { "\($0) nouveaux" },
        quizTitle: "QCM",
        quizDesc: "Texte à trous · Et ensuite ?",
        mistakes: { "\($0) erreurs à revoir" },
        perRound: { "\($0) par série" },
        vocab: "Vocabulaire",
        quizProgress: "Questions",
        total: { "\($0) au total" },
        tabLearn: "Apprendre",
        tabWords: "Mots",
        tapToReveal: "Touche pour voir le sens",
        known: "Je connais",
        unknown: "Je ne sais pas",
        undo: "Annuler",
        undone: "Annulé",
        roundDone: "Série terminée !",
        roundHint: "Les mots inconnus reviendront dans quelques heures",
        goQuiz: "Passer au QCM",
        again: "Encore une série",
        fill: "Texte à trous",
        next: "Et ensuite ?",
        fillHint: "Choisis le mot qui complète la phrase",
        nextHint: "Choisis la suite la plus naturelle",
        showTranslation: "Voir la traduction",
        check: "Vérifier",
        correct: "Bravo !",
        correctAnswer: "Bonne réponse : ",
        continue: "Continuer",
        yourChoice: "Votre choix",
        tapWordHint: "Touchez un mot pour voir sa traduction",
        addWord: "Ajouter à mes mots",
        wordAdded: "Ajouté ✓",
        noGloss: "Pas de traduction disponible",
        custom: "Perso",
        remove: "Retirer",
        quizDone: "Entraînement terminé",
        accuracy: { "\($0) % de bonnes réponses" },
        quizDoneHint: "Les questions ratées reviendront plus vite",
        backHome: "Retour à l'accueil",
        wordsTitle: "Mots",
        search: "Chercher un mot ou un sens",
        all: "Tous",
        dueNow: "À revoir",
        inHours: { "dans \($0) h" },
        inDays: { "dans \($0) j" },
        notLearned: "pas commencé",
        noMatch: "Aucun mot trouvé",
        server: "Serveur"
    )

    static let es = Strings(
        langName: [.zh: "chino", .en: "inglés", .fr: "francés", .es: "español"],
        pos: ["n": "sust.", "v": "verbo", "adj": "adj.", "adv": "adv.", "pron": "pron.", "prep": "prep.", "conj": "conj.", "num": "número", "interj": "interj.", "phr": "expresión", "det": "det.", "name": "nombre propio", "part": "partícula"],
        level: [.new: "Nueva", .learning: "Aprendiendo", .familiar: "Conocida", .mastered: "Dominada"],
        gender: [.m: "masculino", .f: "femenino", .mf: "m/f"],
        skill: [.vocab: "Vocabulario", .form: "Formas", .context: "Diálogo"],
        vocabHint: "Elige la palabra que falta",
        formHint: "Elige la forma correcta",
        quizLocked: "Primero repasa algunas palabras: las preguntas se desbloquean con tu vocabulario",
        goSwipe: "Repasar palabras",
        lv: { "Nv. \($0)" },
        signInSubtitle: "Palabras, preguntas y un poco de progreso cada día",
        signInGoogle: "Iniciar sesión con Google",
        signInError: ["cancelled": "Inicio de sesión cancelado", "state": "La sesión caducó, inténtalo de nuevo", "failed": "No se pudo iniciar sesión, inténtalo de nuevo"],
        account: "Cuenta",
        signOut: "Cerrar sesión",
        getStarted: "Empezar",
        myLanguage: "Hablo",
        iWantToLearn: "Quiero aprender",
        learningPair: { "Aprender \($1) desde \($0)" },
        start: "Empezar",
        save: "Guardar",
        loading: "Cargando…",
        error: "Algo salió mal: ¿está funcionando el servidor?",
        retry: "Reintentar",
        dailyGoal: { "Meta diaria: \($0) repasos" },
        remaining: { "Faltan \($0): ¡mantén tu racha!" },
        goalDone: "Meta diaria cumplida 🎉",
        streakDays: { "\($0) d" },
        practice: "Práctica",
        swipeTitle: "Palabras rápidas",
        swipeDesc: "Desliza a la derecha si la sabes, a la izquierda si no; toca para ver el significado",
        due: { "\($0) por repasar" },
        newCount: { "\($0) nuevas" },
        quizTitle: "Opción múltiple",
        quizDesc: "Completa la frase · ¿Qué sigue?",
        mistakes: { "\($0) errores por repasar" },
        perRound: { "\($0) por ronda" },
        vocab: "Vocabulario",
        quizProgress: "Preguntas",
        total: { "\($0) en total" },
        tabLearn: "Aprender",
        tabWords: "Palabras",
        tapToReveal: "Toca para ver el significado",
        known: "La sé",
        unknown: "No la sé",
        undo: "Deshacer",
        undone: "Deshecho",
        roundDone: "¡Ronda completada!",
        roundHint: "Las palabras que no sabías volverán en unas horas",
        goQuiz: "Practicar con preguntas",
        again: "Otra ronda",
        fill: "Completa la frase",
        next: "¿Qué sigue?",
        fillHint: "Elige la palabra que completa la frase",
        nextHint: "Elige la respuesta más natural",
        showTranslation: "Ver traducción",
        check: "Comprobar",
        correct: "¡Muy bien!",
        correctAnswer: "Respuesta correcta: ",
        continue: "Continuar",
        yourChoice: "Tu elección",
        tapWordHint: "Toca una palabra para ver qué significa",
        addWord: "Añadir a mis palabras",
        wordAdded: "Añadida ✓",
        noGloss: "No hay traducción",
        custom: "Personal",
        remove: "Quitar",
        quizDone: "Práctica completada",
        accuracy: { "\($0) % de aciertos" },
        quizDoneHint: "Las preguntas falladas volverán antes",
        backHome: "Volver al inicio",
        wordsTitle: "Palabras",
        search: "Buscar palabras o significados",
        all: "Todas",
        dueNow: "Por repasar",
        inHours: { "en \($0) h" },
        inDays: { "en \($0) d" },
        notLearned: "sin empezar",
        noMatch: "No hay palabras",
        server: "Servidor"
    )
}
