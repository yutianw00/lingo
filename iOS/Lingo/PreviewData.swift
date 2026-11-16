#if DEBUG
import Foundation

/// Canned backend responses for SwiftUI previews (the Xcode canvas): no server, no sign-in,
/// and the screens stay interactive (answering, swiping, adding words all "work").
/// Captured from a local backend: Spanish course, Chinese native language. Debug builds only,
/// and only active while Xcode is rendering a preview, or when the app is launched with
/// `-previewData` (the whole app then runs offline on this data; `API.send` checks `isActive`).
enum PreviewData {
    static let isActive = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        || ProcessInfo.processInfo.arguments.contains("-previewData")

    static var me: Me {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try! d.decode(Me.self, from: data(fixtures["me"]!))
    }

    /// The response body for one API call, as the real backend would send it (snake_case JSON).
    static func respond(_ method: String, _ path: String, body: Data?) throws -> Data {
        let p = path.split(separator: "/").map { $0.removingPercentEncoding ?? String($0) }
        let input = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let ok: [String: Any] = ["ok": true]
        /// Matches `verb` and a path like "quiz/*/answer"; returns the `*` parts.
        func route(_ verb: String, _ pattern: String) -> [String]? {
            let q = pattern.split(separator: "/").map(String.init)
            guard method == verb, q.count == p.count else { return nil }
            var parts: [String] = []
            for (a, b) in zip(q, p) {
                if a == "*" { parts.append(b) } else if a != b { return nil }
            }
            return parts
        }

        if route("GET", "auth/config") != nil { return data(["enabled": true, "providers": ["google"]]) }
        if route("POST", "auth/logout") != nil { return data(ok) }
        if route("GET", "me") != nil { return data(fixtures["me"]!) }
        if route("PUT", "me") != nil {
            var me = fixtures["me"] as! [String: Any]
            me.merge(input) { _, new in new }
            return data(me)
        }
        if route("GET", "home") != nil { return data(fixtures["home"]!) }
        if route("GET", "words/session") != nil { return data(fixtures["session"]!) }
        if route("GET", "words") != nil { return data(fixtures["words"]!) }
        if route("POST", "words/*/review") != nil { return data(fixtures["review"]!) }
        if route("POST", "words/*/undo") != nil {
            return data(["mastery": 0, "level": "new", "due": NSNull(), "reps": 0, "lapses": 0])
        }
        if route("POST", "words/custom") != nil {
            var card = (fixtures["words"] as! [[String: Any]]).first { $0["custom"] as? Bool == true }!
            card["id"] = "c-preview-\(input["word"] ?? "")"
            for k in ["word", "meaning", "pos"] { card[k] = input[k] }
            return data(card)
        }
        if route("DELETE", "words/custom/*") != nil { return data(ok) }
        if route("GET", "quiz/session") != nil { return data(fixtures["quiz"]!) }
        if let id = route("GET", "quiz/*/words")?.first {
            return data((fixtures["qwords"] as! [String: Any])[id]!)
        }
        if let id = route("POST", "quiz/*/answer")?.first {
            let byChoice = (fixtures["answers"] as! [String: [String: Any]])[id]!
            return data(byChoice[input["choice"] as? String ?? ""] ?? byChoice.values.first!)
        }
        throw APIError.http(404, "no preview data for \(method) \(path)")
    }

    private static func data(_ v: Any) -> Data { try! JSONSerialization.data(withJSONObject: v) }

    private static let fixtures = try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]

    private static let json = #"""
{
 "me": {
  "id": "demo",
  "native": "zh",
  "target": "es",
  "onboarded": true,
  "daily_goal": 30,
  "email": null,
  "name": "Demo",
  "picture": null
 },
 "home": {
  "native": "zh",
  "target": "es",
  "leveled": true,
  "level": 1,
  "level_score": 0.5,
  "streak": 1,
  "today": {
   "done": 78,
   "goal": 30
  },
  "words": {
   "total": 3020,
   "due": 0,
   "new": 2959,
   "levels": {
    "new": 2959,
    "learning": 22,
    "familiar": 39,
    "mastered": 0
   }
  },
  "quiz": {
   "total": 59,
   "due": 0,
   "new": 57,
   "mistakes": 0,
   "levels": {
    "new": 57,
    "learning": 2,
    "familiar": 0,
    "mastered": 0
   }
  }
 },
 "session": [
  {
   "id": "c-fc15070d4f4e208e",
   "word": "la comida",
   "pos": "n",
   "gender": "",
   "difficulty": 0.0,
   "difficulty_level": 0,
   "topic": "custom",
   "meaning": "食物；饭菜",
   "example": "",
   "example_translation": "",
   "custom": true,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  },
  {
   "id": "es-ocho-num",
   "word": "ocho",
   "pos": "num",
   "gender": "",
   "difficulty": 0.45,
   "difficulty_level": 1,
   "topic": "numbers",
   "meaning": "八",
   "example": "Ceno a las ocho.",
   "example_translation": "我八点吃晚饭。",
   "custom": false,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  },
  {
   "id": "es-me-pron",
   "word": "me",
   "pos": "pron",
   "gender": "",
   "difficulty": 0.5,
   "difficulty_level": 1,
   "topic": "pronouns",
   "meaning": "我（宾格）",
   "example": "Me llamo Carlos.",
   "example_translation": "我叫卡洛斯。",
   "custom": false,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  },
  {
   "id": "es-pan-n-m",
   "word": "el pan",
   "pos": "n",
   "gender": "m",
   "difficulty": 0.45,
   "difficulty_level": 1,
   "topic": "food",
   "meaning": "面包",
   "example": "Compro pan todos los días.",
   "example_translation": "我每天买面包。",
   "custom": false,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  },
  {
   "id": "es-hermana-n-f",
   "word": "la hermana",
   "pos": "n",
   "gender": "f",
   "difficulty": 0.45,
   "difficulty_level": 1,
   "topic": "family",
   "meaning": "姐妹",
   "example": "Mi hermana vive en Lima.",
   "example_translation": "我姐姐住在利马。",
   "custom": false,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  },
  {
   "id": "es-hermano-n-m",
   "word": "el hermano",
   "pos": "n",
   "gender": "m",
   "difficulty": 0.45,
   "difficulty_level": 1,
   "topic": "family",
   "meaning": "兄弟",
   "example": "Tengo un hermano.",
   "example_translation": "我有一个兄弟。",
   "custom": false,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  }
 ],
 "words": [
  {
   "id": "c-fc15070d4f4e208e",
   "word": "la comida",
   "pos": "n",
   "gender": "",
   "difficulty": 0.0,
   "difficulty_level": 0,
   "topic": "custom",
   "meaning": "食物；饭菜",
   "example": "",
   "example_translation": "",
   "custom": true,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  },
  {
   "id": "es-hola-interj",
   "word": "hola",
   "pos": "interj",
   "gender": "",
   "difficulty": 0.1,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "你好",
   "example": "¡Hola, María!",
   "example_translation": "你好，玛丽亚！",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2178729,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-gracias-phr",
   "word": "gracias",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.1,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "谢谢",
   "example": "Muchas gracias por la comida.",
   "example_translation": "非常感谢你的饭菜。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2265751,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-s-adv",
   "word": "sí",
   "pos": "adv",
   "gender": "",
   "difficulty": 0.1,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "是，对",
   "example": "Sí, soy de China.",
   "example_translation": "是的，我是中国人。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2318342,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-no-adv",
   "word": "no",
   "pos": "adv",
   "gender": "",
   "difficulty": 0.1,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "不，没有",
   "example": "No hablo francés.",
   "example_translation": "我不会说法语。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.234142,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-por-favor-phr",
   "word": "por favor",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.15,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "请",
   "example": "Un café, por favor.",
   "example_translation": "请来一杯咖啡。",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.224153,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-adi-s-interj",
   "word": "adiós",
   "pos": "interj",
   "gender": "",
   "difficulty": 0.15,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "再见",
   "example": "Adiós, hasta mañana.",
   "example_translation": "再见，明天见。",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.2389781,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-y-conj",
   "word": "y",
   "pos": "conj",
   "gender": "",
   "difficulty": 0.15,
   "difficulty_level": 1,
   "topic": "little-words",
   "meaning": "和",
   "example": "Café y leche.",
   "example_translation": "咖啡和牛奶。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.221764,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-buenos-d-as-phr",
   "word": "buenos días",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "早上好",
   "example": "Buenos días, señora.",
   "example_translation": "早上好，女士。",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.2366369,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-buenas-noches-phr",
   "word": "buenas noches",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "晚上好；晚安",
   "example": "Buenas noches, hasta mañana.",
   "example_translation": "晚安，明天见。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.229276,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-yo-pron",
   "word": "yo",
   "pos": "pron",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "pronouns",
   "meaning": "我",
   "example": "Yo soy estudiante.",
   "example_translation": "我是学生。",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.230471,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-t-pron",
   "word": "tú",
   "pos": "pron",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "pronouns",
   "meaning": "你",
   "example": "¿Tú eres de Madrid?",
   "example_translation": "你是马德里人吗？",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.222962,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-ser-v",
   "word": "ser",
   "pos": "v",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "core-verbs",
   "meaning": "是（本质、身份）",
   "example": "Quiero ser médico.",
   "example_translation": "我想当医生。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.233112,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-estar-v",
   "word": "estar",
   "pos": "v",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "core-verbs",
   "meaning": "在；处于（状态、位置）",
   "example": "Me gusta estar en casa.",
   "example_translation": "我喜欢待在家里。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.220455,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-de-prep",
   "word": "de",
   "pos": "prep",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "little-words",
   "meaning": "的；来自",
   "example": "Soy de Shanghái.",
   "example_translation": "我来自上海。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2164202,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-en-prep",
   "word": "en",
   "pos": "prep",
   "gender": "",
   "difficulty": 0.2,
   "difficulty_level": 1,
   "topic": "little-words",
   "meaning": "在……里",
   "example": "Estoy en el hotel.",
   "example_translation": "我在酒店。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.219178,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-de-nada-phr",
   "word": "de nada",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "不客气",
   "example": "—Gracias. —De nada.",
   "example_translation": "“谢谢。”“不客气。”",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.227987,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-lo-siento-phr",
   "word": "lo siento",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "对不起，抱歉",
   "example": "Lo siento, no tengo tiempo.",
   "example_translation": "抱歉，我没有时间。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.225287,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-perd-n-phr",
   "word": "perdón",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "对不起；打扰一下",
   "example": "Perdón, ¿dónde está el baño?",
   "example_translation": "打扰一下，洗手间在哪里？",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.237797,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-l-pron",
   "word": "él",
   "pos": "pron",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "pronouns",
   "meaning": "他",
   "example": "Él es mi hermano.",
   "example_translation": "他是我的哥哥。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2149708,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-ella-pron",
   "word": "ella",
   "pos": "pron",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "pronouns",
   "meaning": "她",
   "example": "Ella es mi madre.",
   "example_translation": "她是我的妈妈。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.235439,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-tener-v",
   "word": "tener",
   "pos": "v",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "core-verbs",
   "meaning": "有",
   "example": "Quiero tener un perro.",
   "example_translation": "我想养一只狗。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2601368,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-ir-v",
   "word": "ir",
   "pos": "v",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "core-verbs",
   "meaning": "去",
   "example": "Quiero ir a España.",
   "example_translation": "我想去西班牙。",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.258136,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-a-prep",
   "word": "a",
   "pos": "prep",
   "gender": "",
   "difficulty": 0.25,
   "difficulty_level": 1,
   "topic": "little-words",
   "meaning": "到，向",
   "example": "Voy a Madrid.",
   "example_translation": "我去马德里。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.262312,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-hasta-luego-phr",
   "word": "hasta luego",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.3,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "回头见",
   "example": "Me voy. ¡Hasta luego!",
   "example_translation": "我走了，回头见！",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.255968,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-mucho-gusto-phr",
   "word": "mucho gusto",
   "pos": "phr",
   "gender": "",
   "difficulty": 0.3,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "很高兴认识你",
   "example": "Me llamo Ana, mucho gusto.",
   "example_translation": "我叫安娜，很高兴认识你。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2548192,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-bien-adv",
   "word": "bien",
   "pos": "adv",
   "gender": "",
   "difficulty": 0.3,
   "difficulty_level": 1,
   "topic": "greetings",
   "meaning": "好，很好",
   "example": "Estoy muy bien, gracias.",
   "example_translation": "我很好，谢谢。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2667782,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-usted-pron",
   "word": "usted",
   "pos": "pron",
   "gender": "",
   "difficulty": 0.3,
   "difficulty_level": 1,
   "topic": "pronouns",
   "meaning": "您",
   "example": "¿Cómo está usted?",
   "example_translation": "您好吗？",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.2678468,
   "reps": 1,
   "lapses": 0
  },
  {
   "id": "es-querer-v",
   "word": "querer",
   "pos": "v",
   "gender": "",
   "difficulty": 0.3,
   "difficulty_level": 1,
   "topic": "core-verbs",
   "meaning": "想要；爱",
   "example": "¿Qué vas a querer?",
   "example_translation": "你要点什么？",
   "custom": false,
   "mastery": 3,
   "level": "learning",
   "due": 1794809389.257053,
   "reps": 0,
   "lapses": 1
  },
  {
   "id": "es-hablar-v",
   "word": "hablar",
   "pos": "v",
   "gender": "",
   "difficulty": 0.3,
   "difficulty_level": 1,
   "topic": "core-verbs",
   "meaning": "说，讲",
   "example": "Quiero hablar español.",
   "example_translation": "我想说西班牙语。",
   "custom": false,
   "mastery": 50,
   "level": "familiar",
   "due": 1795396909.246515,
   "reps": 1,
   "lapses": 0
  }
 ],
 "quiz": [
  {
   "id": "es-f301",
   "kind": "fill",
   "skill": "form",
   "difficulty_level": 3,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0,
   "prompt": "Quiero ___ manzana roja.",
   "translation": "我要那个红苹果。",
   "options": [
    {
     "text": "el",
     "translation": null
    },
    {
     "text": "la",
     "translation": null
    },
    {
     "text": "los",
     "translation": null
    },
    {
     "text": "un",
     "translation": null
    }
   ]
  },
  {
   "id": "v-es-ser-v",
   "kind": "fill",
   "skill": "vocab",
   "difficulty_level": 1,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0,
   "prompt": "Quiero ___ médico.",
   "translation": "我想当医生。",
   "options": [
    {
     "text": "parar",
     "translation": null
    },
    {
     "text": "ser",
     "translation": null
    },
    {
     "text": "durar",
     "translation": null
    },
    {
     "text": "traer",
     "translation": null
    }
   ]
  },
  {
   "id": "es-d301",
   "kind": "next",
   "skill": "context",
   "difficulty_level": 3,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0,
   "prompt": "¡Hola! ¿Cómo estás?",
   "translation": "你好！你好吗？",
   "options": [
    {
     "text": "Me llamo Lucía, ¿y tú?",
     "translation": "我叫露西娅，你呢？"
    },
    {
     "text": "Muy bien, gracias. ¿Y tú?",
     "translation": "很好，谢谢。你呢？"
    },
    {
     "text": "Un café con leche, por favor.",
     "translation": "请来一杯牛奶咖啡。"
    },
    {
     "text": "Soy de Shanghái, en China.",
     "translation": "我是中国上海人。"
    }
   ]
  },
  {
   "id": "v-es-gracias-phr",
   "kind": "fill",
   "skill": "vocab",
   "difficulty_level": 1,
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0,
   "prompt": "Muchas ___ por la comida.",
   "translation": "非常感谢你的饭菜。",
   "options": [
    {
     "text": "gracias",
     "translation": null
    },
    {
     "text": "lo siento",
     "translation": null
    },
    {
     "text": "perdón",
     "translation": null
    },
    {
     "text": "por favor",
     "translation": null
    }
   ]
  }
 ],
 "qwords": {
  "es-f301": {
   "text": "Quiero ___ manzana roja.",
   "tokens": [
    {
     "text": "Quiero",
     "word": true,
     "lemma": "querer",
     "meaning": "我想要",
     "lemma_meaning": "想要；爱",
     "pos": "v",
     "added": false
    },
    {
     "text": " ___ ",
     "word": false
    },
    {
     "text": "manzana",
     "word": true,
     "lemma": "la manzana",
     "meaning": "苹果",
     "lemma_meaning": "苹果",
     "pos": "n",
     "added": false
    },
    {
     "text": " ",
     "word": false
    },
    {
     "text": "roja",
     "word": true,
     "lemma": "rojo",
     "meaning": "红色的（阴性）",
     "lemma_meaning": "红色的",
     "pos": "adj",
     "added": false
    },
    {
     "text": ".",
     "word": false
    }
   ]
  },
  "v-es-ser-v": {
   "text": "Quiero ___ médico.",
   "tokens": [
    {
     "text": "Quiero",
     "word": true,
     "lemma": "querer",
     "meaning": "我想要",
     "lemma_meaning": "想要；爱",
     "pos": "v",
     "added": false
    },
    {
     "text": " ___ ",
     "word": false
    },
    {
     "text": "médico",
     "word": true,
     "lemma": "el médico",
     "meaning": "医生",
     "lemma_meaning": "医生",
     "pos": "n",
     "added": false
    },
    {
     "text": ".",
     "word": false
    }
   ]
  },
  "es-d301": {
   "text": "¡Hola! ¿Cómo estás?",
   "tokens": [
    {
     "text": "¡",
     "word": false
    },
    {
     "text": "Hola",
     "word": true,
     "lemma": "hola",
     "meaning": "你好",
     "lemma_meaning": "你好",
     "pos": "interj",
     "added": false
    },
    {
     "text": "! ¿",
     "word": false
    },
    {
     "text": "Cómo",
     "word": true,
     "lemma": "cómo",
     "meaning": "怎样，如何",
     "lemma_meaning": "怎样，如何",
     "pos": "adv",
     "added": false
    },
    {
     "text": " ",
     "word": false
    },
    {
     "text": "estás",
     "word": true,
     "lemma": "estar",
     "meaning": "你在；你（好吗）",
     "lemma_meaning": "在；处于（状态、位置）",
     "pos": "v",
     "added": false
    },
    {
     "text": "?",
     "word": false
    }
   ]
  },
  "v-es-gracias-phr": {
   "text": "Muchas ___ por la comida.",
   "tokens": [
    {
     "text": "Muchas",
     "word": true,
     "lemma": "mucho",
     "meaning": "很多（阴性复数）（muchas gracias 非常感谢）",
     "lemma_meaning": "很多；非常",
     "pos": "det",
     "added": false
    },
    {
     "text": " ___ ",
     "word": false
    },
    {
     "text": "por",
     "word": true,
     "lemma": "por",
     "meaning": "通过；因为；在……期间",
     "lemma_meaning": "通过；因为；在……期间",
     "pos": "prep",
     "added": false
    },
    {
     "text": " ",
     "word": false
    },
    {
     "text": "la",
     "word": true,
     "lemma": "la",
     "meaning": "（阴性定冠词）；她/它（宾语）",
     "lemma_meaning": "（阴性定冠词）；她/它（宾语）",
     "pos": "det",
     "added": false
    },
    {
     "text": " ",
     "word": false
    },
    {
     "text": "comida",
     "word": true,
     "lemma": "la comida",
     "meaning": "食物；饭菜",
     "lemma_meaning": "食物；饭菜",
     "pos": "n",
     "added": false
    },
    {
     "text": ".",
     "word": false
    }
   ]
  }
 },
 "answers": {
  "es-f301": {
   "el": {
    "correct": false,
    "answer": "la",
    "full_sentence": "Quiero la manzana roja.",
    "translation": "我要那个红苹果。",
    "explanation": "manzana 是阴性单数名词，用 la",
    "choice_explanation": "el 是阳性冠词，manzana 是阴性",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "la": {
    "correct": true,
    "answer": "la",
    "full_sentence": "Quiero la manzana roja.",
    "translation": "我要那个红苹果。",
    "explanation": "manzana 是阴性单数名词，用 la",
    "choice_explanation": null,
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 12,
     "level": "learning",
     "due": null,
     "reps": 1,
     "lapses": 0
    }
   },
   "los": {
    "correct": false,
    "answer": "la",
    "full_sentence": "Quiero la manzana roja.",
    "translation": "我要那个红苹果。",
    "explanation": "manzana 是阴性单数名词，用 la",
    "choice_explanation": "los 是阳性复数，这里只有一个苹果",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "un": {
    "correct": false,
    "answer": "la",
    "full_sentence": "Quiero la manzana roja.",
    "translation": "我要那个红苹果。",
    "explanation": "manzana 是阴性单数名词，用 la",
    "choice_explanation": "un 是阳性不定冠词，而且这里指特定的“那个”苹果",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   }
  },
  "v-es-ser-v": {
   "parar": {
    "correct": false,
    "answer": "ser",
    "full_sentence": "Quiero ser médico.",
    "translation": "我想当医生。",
    "explanation": "“ser”的意思是“是（本质、身份）”，正是这句话需要的词。",
    "choice_explanation": "“parar”的意思是“停”，放在这句话里意思不通。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "ser": {
    "correct": true,
    "answer": "ser",
    "full_sentence": "Quiero ser médico.",
    "translation": "我想当医生。",
    "explanation": "“ser”的意思是“是（本质、身份）”，正是这句话需要的词。",
    "choice_explanation": null,
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 12,
     "level": "learning",
     "due": null,
     "reps": 1,
     "lapses": 0
    }
   },
   "durar": {
    "correct": false,
    "answer": "ser",
    "full_sentence": "Quiero ser médico.",
    "translation": "我想当医生。",
    "explanation": "“ser”的意思是“是（本质、身份）”，正是这句话需要的词。",
    "choice_explanation": "“durar”的意思是“持续”，放在这句话里意思不通。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "traer": {
    "correct": false,
    "answer": "ser",
    "full_sentence": "Quiero ser médico.",
    "translation": "我想当医生。",
    "explanation": "“ser”的意思是“是（本质、身份）”，正是这句话需要的词。",
    "choice_explanation": "“traer”的意思是“带来”，放在这句话里意思不通。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   }
  },
  "es-d301": {
   "Me llamo Lucía, ¿y tú?": {
    "correct": false,
    "answer": "Muy bien, gracias. ¿Y tú?",
    "full_sentence": "¡Hola! ¿Cómo estás? Muy bien, gracias. ¿Y tú?",
    "translation": "你好！你好吗？ 很好，谢谢。你呢？",
    "explanation": "“Muy bien, gracias. ¿Y tú?”是对“¡Hola! ¿Cómo estás?”自然的回应。",
    "choice_explanation": "这句是在回应“¿Cómo te llamas?”（你叫什么名字？），和这里的话接不上。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "Muy bien, gracias. ¿Y tú?": {
    "correct": true,
    "answer": "Muy bien, gracias. ¿Y tú?",
    "full_sentence": "¡Hola! ¿Cómo estás? Muy bien, gracias. ¿Y tú?",
    "translation": "你好！你好吗？ 很好，谢谢。你呢？",
    "explanation": "“Muy bien, gracias. ¿Y tú?”是对“¡Hola! ¿Cómo estás?”自然的回应。",
    "choice_explanation": null,
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 12,
     "level": "learning",
     "due": null,
     "reps": 1,
     "lapses": 0
    }
   },
   "Un café con leche, por favor.": {
    "correct": false,
    "answer": "Muy bien, gracias. ¿Y tú?",
    "full_sentence": "¡Hola! ¿Cómo estás? Muy bien, gracias. ¿Y tú?",
    "translation": "你好！你好吗？ 很好，谢谢。你呢？",
    "explanation": "“Muy bien, gracias. ¿Y tú?”是对“¡Hola! ¿Cómo estás?”自然的回应。",
    "choice_explanation": "这句是在回应“¿Qué quieres tomar?”（你想喝点什么？），和这里的话接不上。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "Soy de Shanghái, en China.": {
    "correct": false,
    "answer": "Muy bien, gracias. ¿Y tú?",
    "full_sentence": "¡Hola! ¿Cómo estás? Muy bien, gracias. ¿Y tú?",
    "translation": "你好！你好吗？ 很好，谢谢。你呢？",
    "explanation": "“Muy bien, gracias. ¿Y tú?”是对“¡Hola! ¿Cómo estás?”自然的回应。",
    "choice_explanation": "这句是在回应“¿De dónde eres?”（你是哪里人？），和这里的话接不上。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   }
  },
  "v-es-gracias-phr": {
   "gracias": {
    "correct": true,
    "answer": "gracias",
    "full_sentence": "Muchas gracias por la comida.",
    "translation": "非常感谢你的饭菜。",
    "explanation": "“gracias”的意思是“谢谢”，正是这句话需要的词。",
    "choice_explanation": null,
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 12,
     "level": "learning",
     "due": null,
     "reps": 1,
     "lapses": 0
    }
   },
   "lo siento": {
    "correct": false,
    "answer": "gracias",
    "full_sentence": "Muchas gracias por la comida.",
    "translation": "非常感谢你的饭菜。",
    "explanation": "“gracias”的意思是“谢谢”，正是这句话需要的词。",
    "choice_explanation": "“lo siento”的意思是“对不起，抱歉”，放在这句话里意思不通。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "perdón": {
    "correct": false,
    "answer": "gracias",
    "full_sentence": "Muchas gracias por la comida.",
    "translation": "非常感谢你的饭菜。",
    "explanation": "“gracias”的意思是“谢谢”，正是这句话需要的词。",
    "choice_explanation": "“perdón”的意思是“对不起；打扰一下”，放在这句话里意思不通。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   },
   "por favor": {
    "correct": false,
    "answer": "gracias",
    "full_sentence": "Muchas gracias por la comida.",
    "translation": "非常感谢你的饭菜。",
    "explanation": "“gracias”的意思是“谢谢”，正是这句话需要的词。",
    "choice_explanation": "“por favor”的意思是“请”，放在这句话里意思不通。",
    "before": {
     "mastery": 0,
     "level": "new",
     "due": null,
     "reps": 0,
     "lapses": 0
    },
    "after": {
     "mastery": 3,
     "level": "learning",
     "due": null,
     "reps": 0,
     "lapses": 1
    }
   }
  }
 },
 "review": {
  "grade": "swipe_known",
  "before": {
   "mastery": 0,
   "level": "new",
   "due": null,
   "reps": 0,
   "lapses": 0
  },
  "after": {
   "mastery": 50,
   "level": "familiar",
   "due": 1795396957.5023491,
   "reps": 1,
   "lapses": 0
  }
 }
}
"""#
}

extension AppModel {
    /// A model for previews: signed in as the fixture user unless another phase is given.
    static func preview(_ phase: Phase? = nil) -> AppModel {
        let m = AppModel()
        m.phase = phase ?? .ready(PreviewData.me)
        return m
    }
}
#endif
