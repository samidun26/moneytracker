import Foundation

/// The word lists behind the Duit Terminal, ported from the prototype
/// (design/prototype/Main.dc.html: SLANG, NUMW, THOUSAND, MILLION, STOP,
/// ACCT_WORDS, DAY_WORDS, INCOME_WORDS, CAT_WORDS). Category words map to
/// the default category *names* (see DefaultCategories), which are looked up
/// in the user's real categories when an entry is saved.
enum SlangVocabulary {
    /// Indonesian money slang. Values under 1,000 are read as thousands.
    static let slang: [String: Int] = [
        "cepek": 100, "gopek": 500, "gocap": 50, "jigo": 25, "seceng": 1000, "noceng": 2000,
        "goceng": 5000, "ceban": 10000, "goban": 50000, "ceti": 1_000_000, "cetiao": 1_000_000,
        "gotiao": 5_000_000,
    ]

    static let numberWords: [String: Double] = [
        "nol": 0, "satu": 1, "dua": 2, "tiga": 3, "empat": 4, "lima": 5, "enam": 6, "tujuh": 7,
        "delapan": 8, "sembilan": 9, "sepuluh": 10, "sebelas": 11, "setengah": 0.5,
    ]

    static let thousand: Set<String> = ["rb", "ribu", "rebu", "k", "rbu"]
    static let million: Set<String> = ["jt", "juta", "jeti"]

    /// Filler words dropped from a title ("beli", "bayar", "pakai"...).
    static let stopWords: Set<String> = [
        "beli", "bayar", "pakai", "pake", "via", "buat", "untuk", "utk", "dan", "yang", "yg", "di", "harga", "rp",
    ]

    /// Words that name a kind of account; resolved to the user's first account of that kind.
    static let accountAliases: [String: AccountKind] = [
        "gopay": .ewallet, "gopey": .ewallet, "gp": .ewallet, "ovo": .ewallet, "dana": .ewallet,
        "shopeepay": .ewallet, "linkaja": .ewallet,
        "cash": .cash, "tunai": .cash, "kes": .cash,
        "bca": .bank, "bni": .bank, "bri": .bank, "mandiri": .bank, "jago": .bank, "debit": .bank, "atm": .bank,
        "visa": .credit, "cc": .credit, "kartu": .credit,
    ]

    /// Days back from today.
    static let dayWords: [String: Int] = [
        "kemarin": -1, "kemaren": -1, "kmrn": -1, "tadi": 0, "barusan": 0, "sekarang": 0,
    ]

    /// Words that turn an entry into income, and which income category they mean.
    static let incomeWords: [String: String] = [
        "gaji": "Salary", "gajian": "Salary", "salary": "Salary",
        "thr": "Bonus & THR", "bonus": "Bonus & THR",
        "freelance": "Freelance", "proyek": "Freelance", "project": "Freelance",
        "dapat": "Other", "dapet": "Other", "terima": "Other", "refund": "Other", "cashback": "Other",
    ]

    /// Words that hint at an expense category.
    static let categoryWords: [String: String] = {
        let rows: [(String, String)] = [
            ("Food & Drinks", "mie mi bakso nasi sate soto ayam bebek makan warteg padang gofood grabfood shopeefood martabak pecel gado siomay seblak burger pizza bubur geprek mcd kfc lalapan ketoprak rendang uduk lontong"),
            ("Coffee & Snacks", "kopi coffee kenangan starbucks fore janji teh boba chatime jajan snack cemilan es"),
            ("Transport", "bensin pertamax pertalite parkir grab gojek gocar grabcar ojek ojol krl mrt transjakarta tol taksi bluebird kereta busway"),
            ("Groceries", "indomaret alfamart superindo hypermart sayur belanja pasar beras telur galon minyak indomie"),
            ("Bills & Utilities", "listrik pln token pulsa kuota internet indihome wifi pdam iuran admin"),
            ("Subscriptions", "netflix spotify youtube icloud disney vidio langganan premium"),
            ("Shopping", "shopee tokopedia tokped lazada baju sepatu uniqlo celana tas zara ikea"),
            ("Entertainment", "bioskop nonton cgv xxi game karaoke konser steam"),
            ("Health", "apotek obat dokter klinik vitamin bpjs halodoc"),
            ("Family", "ortu mama papa ibu bapak kiriman adik kakak anak"),
            ("Housing", "kos kost kontrakan sewa apartemen"),
        ]
        var map: [String: String] = [:]
        for (name, words) in rows {
            for word in words.split(separator: " ") { map[String(word)] = name }
        }
        return map
    }()

    /// "mie ayam" → "Mie Ayam"
    static func titleCase(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: true)
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
