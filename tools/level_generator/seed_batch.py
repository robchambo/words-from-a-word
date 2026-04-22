"""
Batch analysis of candidate source words across all P1-P5 profiles.
Shows required words, gap_ratio, multi-profile eligibility, and
required-word overlap between source words in the same profile.

Usage:
    py seed_batch.py
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import generate_ru as g

CACHE_FILE = os.path.join(g.SCRIPT_DIR, 'vocab_cache_ru.json')
PROFILE_ORDER = ['P1_BEGINNER', 'P2_EASY', 'P3_MEDIUM', 'P4_HARD', 'P5_EXPERT']
COUNT_MIN = 5
COUNT_MAX = 20   # include trim candidates

# Large pool of candidate source words (5-15 letters, all nouns)
CANDIDATES = [
    # 5-letter
    'весна', 'осень', 'город', 'школа', 'книга', 'земля', 'кошка', 'масло',
    'слово', 'слива', 'груша', 'лимон', 'перец', 'берег', 'голос', 'ветер',
    'белка', 'волна', 'сосна', 'карта', 'нитка', 'сумка', 'театр', 'танец',
    'пирог', 'замок', 'каток', 'поход', 'баран', 'рынок', 'певец', 'тесто',
    'место', 'горло', 'армия', 'барин', 'носок', 'камин', 'лампа', 'салат',
    'класс', 'налог', 'мрамор', 'берет', 'корма', 'катер', 'рогач', 'кедр',
    'парус', 'номер', 'народ', 'пакет', 'роман', 'сабля', 'нарост', 'тополь',
    'отряд', 'завод', 'сарай', 'паром', 'порок', 'сокол', 'метро',
    # 6-letter
    'береза', 'малина', 'рябина', 'работа', 'золото', 'родина', 'страна',
    'правда', 'сирень', 'корона', 'калина', 'ладонь', 'посуда', 'дорога',
    'облако', 'яблоко', 'собака', 'машина', 'солдат', 'топор', 'рубаха',
    'слеза', 'корень', 'терем', 'монета', 'полоса', 'серпом', 'порода',
    'сторож', 'лопата', 'забота', 'кастет', 'матрос', 'сапоги', 'сметана',
    'помада', 'парада', 'летчик', 'лапоть', 'кровать', 'сентябрь',
    'дорожка', 'ромашка',
    # 7-letter
    'картина', 'корзина', 'комната', 'природа', 'деревня', 'ромашка',
    'столица', 'тарелка', 'молоток', 'сторона', 'загадка', 'скрипка',
    'лопатка', 'воронка', 'коробка', 'варенье', 'лесенка', 'солянка',
    'болтанка', 'горошек', 'петушок', 'медведь', 'лошадка', 'рубашка',
    'пальтой', 'кружка', 'книжка', 'светлая', 'самовар', 'сметана',
    'окрошка', 'колбаса', 'помидор', 'огурец', 'кабачок', 'черника',
    'перрон', 'матрона', 'поленья', 'тетрадь', 'капуста', 'морковь',
    'осколок', 'монастырь', 'степень', 'лекарство',
    # 8-letter
    'клубника', 'картошка', 'морковка', 'перчатка', 'половина', 'столетие',
    'корзинка', 'коленка', 'скатерть', 'половник', 'терновник', 'ягодница',
    'черепаха', 'самолёт', 'каникулы', 'прогулка', 'рубашечка', 'колдунья',
    'мясорубка', 'картотека', 'свободен', 'сапожник',
    # 9-10+ letter
    'библиотека', 'телевизор', 'украшение', 'население', 'воспитание',
    'образование', 'достижение', 'архитектура', 'государство', 'университет',
    'строитель', 'переводчик', 'сотрудник', 'правительство', 'холодильник',
    'расстояние', 'произведение', 'приключение', 'направление', 'литература',
    'математика', 'территория', 'комсомолец', 'самоделкин',

    # --- additional candidates ---
    # 5-letter (new)
    'актер', 'вагон', 'венок', 'горох', 'жилет', 'козел', 'крест',
    'масть', 'миска', 'мороз', 'мотор', 'набор', 'петух', 'пилот',
    'повар', 'почта', 'разум', 'рыбак', 'сахар', 'семья', 'собор',
    'совет', 'тыква', 'туман', 'уголь', 'узор', 'ферма', 'форма',
    'чашка', 'шапка', 'шахта', 'шишка', 'якорь',
    # 6-letter (new)
    'вокзал', 'горилла', 'дворец', 'журавль', 'камень', 'клавиш',
    'клубок', 'кобура', 'колено', 'копыто', 'кресло', 'лисица',
    'лошадь', 'молния', 'монах', 'музыка', 'наушник', 'облако',
    'олений', 'орлица', 'ошейник', 'павлин', 'палуба', 'пещера',
    'плотник', 'поляна', 'ракета', 'ремень', 'речка', 'рогоз',
    'рубеж', 'рябчик', 'сережка', 'сирота', 'скакун', 'солома',
    'сорока', 'список', 'страус', 'тревога', 'тропик', 'тундра',
    'туника', 'учеба', 'хижина', 'цветок', 'чайник', 'чулок',
    'шкатулка', 'штурман',
    # 7-letter (new)
    'батарея', 'больница', 'борщевик', 'веранда', 'галерея',
    'горница', 'дельфин', 'доктора', 'ежевика', 'журавли',
    'иголка', 'история', 'кабина', 'каравай', 'кастрюля',
    'качалка', 'клубника', 'кожаный', 'колокол', 'корзина',
    'кормилец', 'красота', 'крылатый', 'кувшин', 'лесник',
    'лопасть', 'любовь', 'надежда', 'нарядный', 'наседка',
    'носилки', 'облачко', 'охотник', 'палочка', 'парашют',
    'пекарня', 'перчинка', 'плетень', 'подарок', 'поездка',
    'покрывало', 'полянка', 'помощник', 'портрет', 'потолок',
    'пружина', 'радость', 'ракушка', 'рассвет', 'рогатка',
    'скворец', 'слесарь', 'снегирь', 'солнышко', 'сторонка',
    'стрелка', 'таблица', 'телячий', 'тишина', 'торговля',
    'тренога', 'учитель', 'хлопушка', 'художник', 'черешня',
    'чернила', 'чердак', 'чулочки',
    # 8-letter (new)
    'балалайка', 'бородатый', 'варежки', 'ветеринар', 'горожанин',
    'гречневый', 'дружелюбный', 'засолка', 'изюмина', 'калоши',
    'карандаш', 'кастрюля', 'колючка', 'колыбель', 'конфета',
    'коромысло', 'крепость', 'ласточка', 'линейка', 'лисёнок',
    'лопасти', 'лукошко', 'наперсток', 'нарцисс', 'носилки',
    'носорог', 'обочина', 'орешник', 'парусник', 'пасеника',
    'перебор', 'переулок', 'пестрота', 'плотница', 'погремушка',
    'подснежник', 'пожарник', 'покрышка', 'поляница', 'портфель',
    'рябинка', 'садовник', 'самовар', 'сахарница', 'светлячок',
    'скалолаз', 'скамейка', 'скрипачка', 'смородина', 'собачонка',
    'стекольщик', 'студенческий', 'телефон', 'терраса', 'трактирщик',
    'ушанка', 'фонтан', 'хлебница', 'цыпленок', 'чернобровый',
    'чистота', 'шоколад', 'щепотка',
    # 9-10+ letter (new)
    'балерина', 'велосипед', 'воробушек', 'гостиница', 'дирижер',
    'дорожный', 'жаворонок', 'заготовка', 'знаменитый', 'известность',
    'инженерный', 'история', 'колокольня', 'комбинация', 'кормилица',
    'кулинария', 'лаборатория', 'механизм', 'наблюдение', 'написание',
    'ноябрьский', 'орнамент', 'пассажир', 'переменный', 'перестройка',
    'печенье', 'пианистка', 'пирожное', 'пластилин', 'плотничать',
    'подоконник', 'покрывало', 'помощница', 'попугайчик', 'праздник',
    'пришелец', 'провинция', 'путешествие', 'путешественник',
    'рыболовный', 'свидетель', 'скворечник', 'скотоводство',
    'смородина', 'снегопад', 'солнечный', 'сотрудница', 'специальность',
    'станица', 'стипендия', 'толокно', 'украинский', 'чародей',
    'чистильщик', 'шоколадный',
]


def load_vocab():
    print(f"Loading vocab cache...")
    with open(CACHE_FILE, encoding='utf-8') as f:
        data = json.load(f)
    vocab = [tuple(e) for e in data]
    print(f"  {len(vocab):,} lemmas loaded.")
    return vocab


def build_candidates(source_word, vocab):
    src_counts = g.letter_counts(source_word.lower())
    src_len = len(source_word)
    return [
        (word, count) for word, count in vocab
        if len(word) < src_len and g.can_form(word, src_counts)
    ]


def get_required(candidates, profile):
    pr = g.PROFILES[profile]
    words = [(w, c) for w, c in candidates
             if pr['min_length'] <= len(w) <= pr['max_length']
             and c >= pr['freq_threshold']
             and w not in g.BONUS_ONLY
             and w not in g.FUNCTION_WORDS]
    words.sort(key=lambda x: x[1], reverse=True)
    return words


def gap_ratio(candidates, profile):
    pr = g.PROFILES[profile]
    window = sorted(
        [(w, c) for w, c in candidates
         if pr['min_length'] <= len(w) <= pr['max_length']],
        key=lambda x: x[1], reverse=True
    )
    req = [c for _, c in window if c >= pr['freq_threshold']]
    exc = [c for _, c in window if c < pr['freq_threshold']]
    if not req or not exc:
        return None
    return req[-1] / exc[0]


def gap_label(gr):
    if gr is None:
        return '    —'
    if gr >= 4.0:
        return f'{gr:5.1f} [clean]'
    if gr >= 2.0:
        return f'{gr:5.1f} [decent]'
    return f'{gr:5.1f} [soft]'


def word_overlap_pct(set_a, set_b):
    if not set_a or not set_b:
        return 0.0
    return len(set_a & set_b) / min(len(set_a), len(set_b)) * 100


def main():
    vocab = load_vocab()

    # Deduplicate and validate candidates
    seen = set()
    valid = []
    for w in CANDIDATES:
        w = w.lower().strip()
        if w in seen or len(w) < 5:
            continue
        seen.add(w)
        valid.append(w)
    print(f"\n{len(valid)} candidate source words to evaluate\n")

    # Compute per-word data
    results = {}
    for src in valid:
        cands = build_candidates(src, vocab)
        req = {p: get_required(cands, p) for p in PROFILE_ORDER}
        gr  = {p: gap_ratio(cands, p) for p in PROFILE_ORDER}
        eligible = [p for p in PROFILE_ORDER
                    if COUNT_MIN <= len(req[p]) <= COUNT_MAX]
        results[src] = {'req': req, 'gr': gr, 'eligible': eligible, 'cands': cands}

    # Print per-profile report
    for profile in PROFILE_ORDER:
        pr = g.PROFILES[profile]
        pshort = profile.split('_')[0]
        print()
        print('=' * 72)
        print(f"{profile}  sub-word len {pr['min_length']}-{pr['max_length']},"
              f"  freq >= {pr['freq_threshold']:,}  (top {pr['percentile']}%)")
        print('=' * 72)

        # Collect words eligible at this profile, sorted by gap_ratio desc
        eligible_here = [
            (src, results[src]['gr'][profile], results[src]['req'][profile],
             results[src]['eligible'])
            for src in valid
            if profile in results[src]['eligible']
        ]
        eligible_here.sort(key=lambda x: (x[1] or 0), reverse=True)

        if not eligible_here:
            print("  (no eligible words found)")
            continue

        # Collect required sets for overlap analysis
        req_sets = {src: set(w for w, _ in results[src]['req'][profile])
                    for src, _, _, _ in eligible_here}

        print(f"  {'Source word':<18} {'len':>4}  {'req':>4}  {'gap':>14}  {'profiles':<28}  required words")
        print(f"  {'-'*72}")

        for src, gr, req_words, elig in eligible_here:
            n = len(req_words)
            trim = ' [trim]' if n > 15 else ''
            multi = ' [MULTI]' if len(elig) > 1 else ''
            profiles_str = ' '.join(p.split('_')[0] for p in elig)
            req_list = '  '.join(w for w, _ in req_words[:12])
            if len(req_words) > 12:
                req_list += f'  ...+{len(req_words)-12}'
            print(f"  {src:<18} {len(src):>4}  {n:>4}{trim:<7}  {gap_label(gr):<14}  "
                  f"{profiles_str:<18}{multi}")
            print(f"    {req_list}")

        # Overlap warnings
        print()
        print(f"  --- Overlap warnings (>50% shared required words) ---")
        warned = False
        srcs = [s for s, _, _, _ in eligible_here]
        for i in range(len(srcs)):
            for j in range(i+1, len(srcs)):
                a, b = srcs[i], srcs[j]
                pct = word_overlap_pct(req_sets[a], req_sets[b])
                if pct >= 50:
                    shared = req_sets[a] & req_sets[b]
                    print(f"  {a} / {b}: {pct:.0f}% overlap — {sorted(shared)}")
                    warned = True
        if not warned:
            print("  (none)")

    # Words with no eligible profile
    no_elig = [src for src in valid if not results[src]['eligible']]
    if no_elig:
        print()
        print('=' * 72)
        print("No eligible profile (too few or too many required words at every profile):")
        for src in no_elig:
            counts = '  '.join(f"{p.split('_')[0]}={len(results[src]['req'][p])}"
                               for p in PROFILE_ORDER)
            print(f"  {src:<20}  {counts}")


if __name__ == '__main__':
    main()
