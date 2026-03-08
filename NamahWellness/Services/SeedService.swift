import Foundation
import SwiftData

enum SeedService {
    static func seed(into context: ModelContext) {
        // Phase IDs
        let menstrualId = UUID().uuidString
        let follicularId = UUID().uuidString
        let ovulatoryId = UUID().uuidString
        let lutealId = UUID().uuidString

        // ── PHASES ──
        let phases = [
            Phase(
                id: menstrualId, name: "Menstrual", slug: "menstrual", dayStart: 1, dayEnd: 5,
                calorieTarget: "1,200", proteinTarget: "~102g", fatTarget: "~44g", carbTarget: "~128g",
                heroEyebrow: "Phase One \u{00b7} Days 1\u{2013}5 \u{00b7} 1,200 Calories",
                heroTitle: "Menstrual \u{2014} Restore & Replenish",
                heroSubtitle: "Estrogen and progesterone are at their floor. Appetite is naturally low \u{2014} we lean into that hard. 1,200 purposeful calories: iron to replace what you\u{2019}re losing, anti-inflammatory foods to ease cramping, everything warm and cooked. No raw vegetables this phase. For South Asians, dal and lentils here are ancestral medicine.",
                phaseDescription: "Estrogen and progesterone are at their floor. Appetite is naturally low \u{2014} we lean into that hard. 1,200 purposeful calories: iron to replace what you\u{2019}re losing, anti-inflammatory foods to ease cramping, everything warm and cooked. No raw vegetables this phase. For South Asians, dal and lentils here are ancestral medicine.",
                exerciseIntensity: "Low",
                saNote: "Red lentil dal, rasam, and spinach-based sabzis are your iron and anti-inflammatory powerhouses this week. Your body knows these foods. The turmeric and cumin already in Indian cooking are genuinely therapeutic for menstrual inflammation \u{2014} not a coincidence. Avoid maida (white flour), packaged snacks, and excess chai this week.",
                color: "#B85252", colorSoft: "#F9EDED", colorMid: "#DFB0B0"
            ),
            Phase(
                id: follicularId, name: "Follicular", slug: "follicular", dayStart: 6, dayEnd: 13,
                calorieTarget: "1,200", proteinTarget: "~108g", fatTarget: "~42g", carbTarget: "~118g",
                heroEyebrow: "Phase Two \u{00b7} Days 6\u{2013}13 \u{00b7} 1,200 Calories",
                heroTitle: "Follicular \u{2014} Rise & Rebuild",
                heroSubtitle: "Estrogen climbs and energy returns. Your metabolism is at its most efficient \u{2014} you actually need fewer calories here because your body processes food better. 1,200 clean, vibrant calories with a fresh, raw-forward emphasis. For South Asian bodies, this is the best phase to be aggressive with the deficit. Your insulin sensitivity peaks here.",
                phaseDescription: "Estrogen climbs and energy returns. Your metabolism is at its most efficient \u{2014} you actually need fewer calories here because your body processes food better. 1,200 clean, vibrant calories with a fresh, raw-forward emphasis. For South Asian bodies, this is the best phase to be aggressive with the deficit. Your insulin sensitivity peaks here.",
                exerciseIntensity: "High",
                saNote: "Your insulin sensitivity is at its highest right now \u{2014} this is the phase where brown rice, quinoa, and whole grain rotis (if you have them) are most forgiving. Fermented foods like homemade yogurt, lassi (unsweetened), or store-bought kefir directly improve the gut microbiome\u{2019}s ability to clear estrogen. Add 1 tsp ground flaxseed daily \u{2014} sprinkle it on anything, it\u{2019}s tasteless and is the single best natural estrogen modulator.",
                color: "#4A8C6A", colorSoft: "#EAF3EE", colorMid: "#A8CFBA"
            ),
            Phase(
                id: ovulatoryId, name: "Ovulatory", slug: "ovulatory", dayStart: 14, dayEnd: 17,
                calorieTarget: "1,200", proteinTarget: "~112g", fatTarget: "~40g", carbTarget: "~120g",
                heroEyebrow: "Phase Three \u{00b7} Days 14\u{2013}17 \u{00b7} 1,200 Calories",
                heroTitle: "Ovulatory \u{2014} Peak & Radiate",
                heroSubtitle: "Peak estrogen. Peak energy. Appetite naturally low \u{2014} we stay at 1,200 and keep it vibrant. Fresh, light, colorful. Zinc and B6 are your key nutrients heading into luteal \u{2014} load them now. For South Asians, this 4-day window is also when raw vegetables are most tolerable and effective for estrogen clearance.",
                phaseDescription: "Peak estrogen. Peak energy. Appetite naturally low \u{2014} we stay at 1,200 and keep it vibrant. Fresh, light, colorful. Zinc and B6 are your key nutrients heading into luteal \u{2014} load them now. For South Asians, this 4-day window is also when raw vegetables are most tolerable and effective for estrogen clearance.",
                exerciseIntensity: "Peak",
                saNote: "Raw vegetables are at their most effective and digestible right now \u{2014} don\u{2019}t hold back on salads. The fiber load from raw vegetables during ovulation is the most efficient way to clear excess estrogen for South Asian women, directly reducing the estrogen dominance that can drive luteal symptoms. Avoid alcohol this entire phase \u{2014} estrogen is high and alcohol amplifies it, making your transition into luteal significantly worse.",
                color: "#C49A3C", colorSoft: "#FBF6E8", colorMid: "#E2CC8A"
            ),
            Phase(
                id: lutealId, name: "Luteal", slug: "luteal", dayStart: 18, dayEnd: 28,
                calorieTarget: "1,500\u{2013}1,600", proteinTarget: "~124g", fatTarget: "~48g", carbTarget: "~162g",
                heroEyebrow: "Phase Four \u{00b7} Days 18\u{2013}28 \u{00b7} 1,500\u{2013}1,600 Cal \u{00b7} You Are Here",
                heroTitle: "Luteal \u{2014} Nourish & Hold",
                heroSubtitle: "Progesterone rises, estrogen starts falling, and your metabolism increases 200\u{2013}300 calories. You\u{2019}re hungrier for a biological reason \u{2014} not willpower failure. 1,500\u{2013}1,600 warming, satisfying calories. Strategic complex carbs to stabilize blood sugar, magnesium for mood, and cooked vegetables only for South Asian digestion. This is your longest and most generous phase.",
                phaseDescription: "Progesterone rises, estrogen starts falling, and your metabolism increases 200\u{2013}300 calories. You\u{2019}re hungrier for a biological reason \u{2014} not willpower failure. 1,500\u{2013}1,600 warming, satisfying calories. Strategic complex carbs to stabilize blood sugar, magnesium for mood, and cooked vegetables only for South Asian digestion. This is your longest and most generous phase.",
                exerciseIntensity: "Moderate",
                saNote: "South Asian women tend to experience more pronounced luteal cravings due to the insulin resistance tendency \u{2014} blood sugar drops harder and you reach for carbs more intensely. The solution is not to restrict carbs but to shift to low-GI versions: sweet potato over white potato, brown rice over white, whole wheat roti over paratha. Dal and sabzis are perfect this phase. Raw cruciferous vegetables cause significantly more bloating in luteal \u{2014} cook everything. This is also when your coffee sensitivity peaks: switch to matcha or cardamom-spiced warm almond milk after your morning cup.",
                color: "#7A5C9C", colorSoft: "#F3EFF8", colorMid: "#C4AADC"
            ),
        ]
        phases.forEach { context.insert($0) }

        // ── MEALS ──
        seedMenstrualMeals(into: context, phaseId: menstrualId)
        seedFollicularMeals(into: context, phaseId: follicularId)
        seedOvulatoryMeals(into: context, phaseId: ovulatoryId)
        seedLutealMeals(into: context, phaseId: lutealId)

        // ── WORKOUTS ──
        seedWorkouts(into: context)

        // ── GROCERY ITEMS ──
        seedGroceries(into: context, menstrualId: menstrualId, follicularId: follicularId, ovulatoryId: ovulatoryId, lutealId: lutealId)

        // ── PHASE REMINDERS ──
        seedReminders(into: context, menstrualId: menstrualId, follicularId: follicularId, ovulatoryId: ovulatoryId, lutealId: lutealId)

        // ── PHASE NUTRIENTS ──
        seedNutrients(into: context, menstrualId: menstrualId, follicularId: follicularId, ovulatoryId: ovulatoryId, lutealId: lutealId)

        // ── INITIAL CYCLE LOG ──
        let log = CycleLog(periodStartDate: "2026-02-24")
        context.insert(log)
    }

    // MARK: - Meal helper

    private static func m(_ ctx: ModelContext, _ phaseId: String, _ day: Int, _ dayLabel: String, _ dayCal: String?, _ type: String, _ time: String, _ cal: String, _ title: String, _ desc: String, _ sa: String? = nil, _ p: Int, _ c: Int, _ f: Int) {
        ctx.insert(Meal(phaseId: phaseId, dayNumber: day, dayLabel: dayLabel, dayCalories: dayCal, mealType: type, time: time, calories: cal, title: title, mealDescription: desc, saNote: sa, proteinG: p, carbsG: c, fatG: f))
    }

    // MARK: - Menstrual Meals (5 days)

    private static func seedMenstrualMeals(into ctx: ModelContext, phaseId id: String) {
        // Day 1
        m(ctx, id, 1, "Day 1", "~1,185 kcal", "lunch", "12:00pm", "~440 kcal \u{00b7} Lunch", "Red Lentil Dal + Brown Rice + Spinach", "1 cup red lentil dal made with turmeric, cumin, garlic, ginger, tomato. \u{00bd} cup brown rice. 1 cup wilted spinach with lemon. Squeeze extra lemon over dal \u{2014} vitamin C doubles iron absorption from the lentils.", "\u{2726} SA note: swap white rice for brown \u{2014} same taste, dramatically lower glucose spike", 24, 58, 8)
        m(ctx, id, 1, "Day 1", "~1,185 kcal", "snack", "3:30pm", "~180 kcal \u{00b7} Snack", "Siggis Yogurt + Walnuts + Honey", "\u{00be} cup Siggis plain, 1 tbsp crushed walnuts, \u{00bd} tsp honey, pinch of cinnamon. Walnuts provide omega-3. Cinnamon is specifically beneficial for South Asian blood sugar regulation.", nil, 15, 16, 9)
        m(ctx, id, 1, "Day 1", "~1,185 kcal", "dinner", "7:00pm", "~565 kcal \u{00b7} Dinner", "Pan-Seared Salmon + Roasted Beets + Brown Rice", "5oz salmon, pan-seared in olive oil with garlic. \u{00bd} cup brown rice. 1 cup roasted beets with balsamic. 2\u{2013}3 squares 85% dark chocolate after. Beets support liver detox of old hormones \u{2014} important at phase transition.", nil, 42, 46, 18)
        // Day 2
        m(ctx, id, 2, "Day 2", "~1,200 kcal", "lunch", "12:00pm", "~460 kcal \u{00b7} Lunch", "Keema-Style Ground Beef Bowl", "4oz lean ground beef cooked with onion, garlic, ginger, cumin, coriander, peas. Over \u{00bd} cup brown rice. 1 cup saut\u{00e9}ed spinach with lemon. Classic keema in a bowl \u{2014} comfort food that\u{2019}s also iron therapy.", "\u{2726} SA note: use minimal oil (1 tsp), skip the ghee today to keep calories clean", 38, 44, 14)
        m(ctx, id, 2, "Day 2", "~1,200 kcal", "snack", "3:30pm", "~160 kcal \u{00b7} Snack", "Bone Broth + Pumpkin Seeds", "1 cup warm bone broth (Kettle & Fire). 1 tbsp pumpkin seeds. Deeply nourishing on heavy flow days. Zero prep. Pumpkin seeds are high in zinc and magnesium.", nil, 11, 4, 9)
        m(ctx, id, 2, "Day 2", "~1,200 kcal", "dinner", "7:00pm", "~580 kcal \u{00b7} Dinner", "Chicken Thighs + Masoor Dal + Roasted Carrots", "2 roasted chicken thighs. \u{00bd} cup masoor (red) dal. 1 cup roasted carrots with cumin. Plain yogurt on the side. The dal doubles your iron intake for the day \u{2014} essential on days 2\u{2013}3 of flow.", nil, 46, 40, 22)
        // Day 3
        m(ctx, id, 3, "Day 3", "~1,195 kcal", "lunch", "12:00pm", "~430 kcal \u{00b7} Lunch", "Turmeric Egg Scramble + Sourdough + Avocado", "3 eggs scrambled with \u{00bd} tsp turmeric, black pepper, wilted spinach. 1 slice sourdough toast. Half an avocado. Turmeric + black pepper (piperine) is one of the most effective natural anti-inflammatory combos \u{2014} directly reduces menstrual cramping.", nil, 24, 28, 22)
        m(ctx, id, 3, "Day 3", "~1,195 kcal", "snack", "3:30pm", "~175 kcal \u{00b7} Snack", "Cottage Cheese + Berries", "\u{00bd} cup Good Culture cottage cheese, \u{00bd} cup blueberries or raspberries. Antioxidants from berries support hormone waste clearance.", nil, 14, 14, 4)
        m(ctx, id, 3, "Day 3", "~1,195 kcal", "dinner", "7:00pm", "~590 kcal \u{00b7} Dinner", "Ginger Salmon + Sweet Potato Mash + Steamed Broccoli", "5oz salmon with fresh ginger-soy glaze. 1 medium sweet potato mashed with coconut milk. 1 cup steamed broccoli with sesame oil. Ginger supports circulation and is a proven anti-cramping agent \u{2014} eat it fresh or grated, not just powdered.", nil, 44, 52, 16)
        // Day 4
        m(ctx, id, 4, "Day 4", "~1,190 kcal", "lunch", "12:00pm", "~450 kcal \u{00b7} Lunch", "Rajma-Inspired Kidney Bean Bowl", "\u{00bd} cup kidney beans in tomato-onion-cumin gravy (homemade or canned rajma). \u{00bd} cup brown rice. 1 soft-boiled egg on top. Roasted red bell pepper on the side for vitamin C + iron absorption. Rajma is legitimately one of the best menstrual foods for South Asian women.", "\u{2726} SA note: Rajma is a lower-GI bean than white rice \u{2014} eat the rajma first, then the rice", 28, 56, 12)
        m(ctx, id, 4, "Day 4", "~1,190 kcal", "snack", "3:30pm", "~165 kcal \u{00b7} Snack", "Apple + Almond Butter", "1 small apple, 1 tbsp almond butter. Light, satisfying. Your appetite is genuinely low right now \u{2014} this is the right amount.", nil, 4, 22, 8)
        m(ctx, id, 4, "Day 4", "~1,190 kcal", "dinner", "7:00pm", "~575 kcal \u{00b7} Dinner", "Chicken & Kale Soup", "Rotisserie chicken shredded into chicken broth. Add kale, white beans, diced tomatoes, garlic, lemon. 1 slice sourdough. Warm, minimal effort, deeply nourishing. One of the easiest high-iron meals in the plan.", nil, 48, 44, 14)
        // Day 5
        m(ctx, id, 5, "Day 5", "~1,205 kcal", "lunch", "12:00pm", "~470 kcal \u{00b7} Lunch", "Steak + Saut\u{00e9}ed Mushrooms + Roasted Potato", "4oz grass-fed sirloin or flank steak. Saut\u{00e9}ed cremini mushrooms with garlic. 1 small roasted potato. Final iron-loading meal before flow ends. Mushrooms provide vitamin D which improves iron metabolism.", nil, 40, 36, 16)
        m(ctx, id, 5, "Day 5", "~1,205 kcal", "snack", "3:30pm", "~170 kcal \u{00b7} Snack", "Siggis + Walnuts + Honey", "\u{00be} cup Siggis plain, 1 tbsp walnuts, drizzle of honey. Energy starting to return \u{2014} you\u{2019}re about to enter follicular tomorrow.", nil, 15, 12, 8)
        m(ctx, id, 5, "Day 5", "~1,205 kcal", "dinner", "7:00pm", "~565 kcal \u{00b7} Dinner", "Baked Salmon + Roasted Beets + Brown Rice", "5oz salmon with lemon and dill. \u{00bd} cup brown rice. 1 cup roasted beets. 3 squares 85% dark chocolate to close. A perfect closing meal for the phase \u{2014} anti-inflammatory, iron-supporting, magnesium finish.", nil, 43, 50, 18)
    }

    // MARK: - Follicular Meals (3 days)

    private static func seedFollicularMeals(into ctx: ModelContext, phaseId id: String) {
        // Day 1
        m(ctx, id, 1, "Day 1", "~1,195 kcal", "lunch", "12:00pm", "~470 kcal \u{00b7} Lunch", "Grilled Chicken Big Salad + Flaxseed", "2 cups mixed greens + arugula, 5oz grilled chicken breast, cherry tomatoes, cucumber, shredded carrot, 1 tbsp ground flaxseed, pumpkin seeds, lemon-tahini dressing. Flaxseed every day this phase \u{2014} no exceptions.", nil, 48, 26, 18)
        m(ctx, id, 1, "Day 1", "~1,195 kcal", "snack", "3:30pm", "~185 kcal \u{00b7} Snack", "Cottage Cheese + Blueberries + Flaxseed", "\u{00bd} cup Good Culture cottage cheese, \u{00bd} cup blueberries, 1 tsp ground flaxseed, drizzle of honey. 90 seconds to make. High protein, high antioxidant.", nil, 14, 18, 4)
        m(ctx, id, 1, "Day 1", "~1,195 kcal", "dinner", "7:00pm", "~540 kcal \u{00b7} Dinner", "Salmon + Quinoa + Sauerkraut", "5oz baked salmon. \u{00bd} cup quinoa. \u{00bc} cup sauerkraut on the side (probiotic \u{2014} gut-estrogen axis). Roasted asparagus with lemon. This phase asparagus is excellent \u{2014} it\u{2019}s a prebiotic that feeds estrogen-clearing gut bacteria.", nil, 44, 40, 18)
        // Day 2
        m(ctx, id, 2, "Day 2", "~1,200 kcal", "lunch", "12:00pm", "~480 kcal \u{00b7} Lunch", "Turkey + Avocado Grain Bowl", "4oz ground turkey (cooked with garlic, cumin), \u{00bd} cup brown rice or farro, \u{00bd} avocado, shredded purple cabbage, pickled red onion, lime juice. Vibrant and energizing \u{2014} matches follicular energy perfectly.", "\u{2726} SA note: eat turkey before rice \u{2014} protein first dramatically lowers the glucose response", 38, 44, 16)
        m(ctx, id, 2, "Day 2", "~1,200 kcal", "snack", "3:30pm", "~170 kcal \u{00b7} Snack", "Apple + Almond Butter", "1 medium apple, 1.5 tbsp almond butter. Vitamin C from the apple supports collagen for connective tissue recovery \u{2014} important as you increase workout intensity this phase.", nil, 5, 26, 9)
        m(ctx, id, 2, "Day 2", "~1,200 kcal", "dinner", "7:00pm", "~550 kcal \u{00b7} Dinner", "Chicken Breast + Roasted Broccoli + Sweet Potato", "5oz grilled chicken breast. 1.5 cups roasted broccoli with lemon and chili flake. \u{00bd} medium sweet potato. Broccoli contains DIM \u{2014} a compound that helps the body break down excess estrogen cleanly. Eat it this phase.", nil, 48, 38, 12)
        // Day 3
        m(ctx, id, 3, "Day 3", "~1,195 kcal", "lunch", "12:00pm", "~460 kcal \u{00b7} Lunch", "Tuna Ni\u{00e7}oise Bowl", "1 can wild tuna in olive oil, 2 soft-boiled eggs, mixed greens, blanched green beans, cherry tomatoes, kalamata olives, capers, Dijon vinaigrette. Zero cooking beyond the eggs. Elegant and satisfying.", nil, 44, 18, 22)
        m(ctx, id, 3, "Day 3", "~1,195 kcal", "snack", "3:30pm", "~175 kcal \u{00b7} Snack", "Siggis + Kiwi + Flaxseed", "\u{00be} cup Siggis, 1 kiwi (sliced), 1 tsp ground flaxseed. Kiwi is high in vitamin C and actinidin which improves protein digestion \u{2014} good combo for a high-protein phase.", nil, 14, 20, 4)
        m(ctx, id, 3, "Day 3", "~1,195 kcal", "dinner", "7:00pm", "~560 kcal \u{00b7} Dinner", "Chicken Stir Fry + Soba Noodles", "5oz chicken stir-fried with bok choy, snap peas, garlic, ginger, tamari. Over \u{00bd} cup cooked soba noodles. Soba is buckwheat \u{2014} a phytoestrogen-friendly whole grain with a significantly lower GI than wheat noodles.", "\u{2726} SA note: soba noodles are far better for your blood sugar than regular noodles or maida-based pasta", 42, 46, 14)
    }

    // MARK: - Ovulatory Meals (2 days)

    private static func seedOvulatoryMeals(into ctx: ModelContext, phaseId id: String) {
        // Day 1
        m(ctx, id, 1, "Day 1", "~1,200 kcal", "lunch", "12:00pm", "~480 kcal \u{00b7} Lunch", "Poke-Style Tuna Bowl", "4oz ahi or canned wild tuna, \u{00bd} cup brown rice, shredded purple cabbage, cucumber, edamame, avocado, scallions. Dress with soy-sesame-ginger. Fresh, colorful, peak-phase food \u{2014} exactly what you\u{2019}ll crave this week.", "\u{2726} SA note: eat edamame and cabbage first \u{2014} both are phytoestrogen-rich and help buffer the estrogen peak", 40, 46, 14)
        m(ctx, id, 1, "Day 1", "~1,200 kcal", "snack", "3:30pm", "~180 kcal \u{00b7} Snack", "Turkey Roll-Ups + Hummus", "4 slices deli turkey, 2 tbsp hummus, cucumber for dipping. Turkey is your zinc + B6 delivery vehicle \u{2014} both directly support the progesterone ramp-up coming in luteal. Start loading now.", nil, 16, 10, 6)
        m(ctx, id, 1, "Day 1", "~1,200 kcal", "dinner", "7:00pm", "~540 kcal \u{00b7} Dinner", "Salmon + Roasted Asparagus + Farro", "5oz herb-crusted salmon, baked. 1 cup roasted asparagus with lemon and olive oil. \u{00bd} cup farro. Asparagus is a prebiotic that feeds the gut bacteria responsible for breaking down excess estrogen \u{2014} at peak estrogen, this is your highest-priority vegetable.", nil, 44, 42, 18)
        // Day 2
        m(ctx, id, 2, "Day 2", "~1,195 kcal", "lunch", "12:00pm", "~460 kcal \u{00b7} Lunch", "Grilled Chicken Citrus Salad", "5oz chicken, sliced. Mixed greens, orange or grapefruit segments, thinly sliced fennel, almonds, goat cheese crumbles, champagne vinaigrette. Fennel supports estrogen detox pathways. Light, elegant, high fiber.", nil, 46, 28, 18)
        m(ctx, id, 2, "Day 2", "~1,195 kcal", "snack", "3:30pm", "~185 kcal \u{00b7} Snack", "Siggis + Pumpkin Seeds + Berries", "\u{00be} cup yogurt, 1 tbsp pumpkin seeds, \u{00bc} cup mixed berries. Pumpkin seeds are one of the highest plant sources of zinc \u{2014} your most important mineral this phase.", nil, 16, 16, 7)
        m(ctx, id, 2, "Day 2", "~1,195 kcal", "dinner", "7:00pm", "~550 kcal \u{00b7} Dinner", "Turkey Lettuce Cup Tacos", "5oz ground turkey with cumin, chili, garlic. Romaine lettuce cups. Pico de gallo, avocado, lime, pumpkin seeds. No tortilla needed \u{2014} light, high-protein, exactly the right portion for this phase.", nil, 44, 22, 24)
    }

    // MARK: - Luteal Meals (5 days)

    private static func seedLutealMeals(into ctx: ModelContext, phaseId id: String) {
        // Day 1
        m(ctx, id, 1, "Day 1", "~1,540 kcal", "lunch", "12:00pm", "~560 kcal \u{00b7} Lunch", "Chicken + Sweet Potato + Tahini Bowl", "Rotisserie chicken 5oz, 1 medium roasted sweet potato, arugula, pumpkin seeds, tahini-lemon dressing. Sweet potato is your optimal luteal carb \u{2014} steady glucose, rich in B6 and potassium which reduce bloating. Eat chicken first.", "\u{2726} SA note: sweet potato has a GI of ~54 vs white potato at ~78 \u{2014} meaningful difference for your insulin response", 46, 54, 18)
        m(ctx, id, 1, "Day 1", "~1,540 kcal", "snack", "3:30pm", "~220 kcal \u{00b7} Snack", "Banana + Almond Butter + Dark Chocolate", "1 banana, 1.5 tbsp almond butter, 2 squares 85% dark chocolate. Specifically anti-PMS: banana raises serotonin, almond butter stabilizes blood sugar, dark chocolate provides magnesium. Have this the moment cravings hit \u{2014} it biochemically works within 20 minutes.", nil, 6, 36, 11)
        m(ctx, id, 1, "Day 1", "~1,540 kcal", "dinner", "7:00pm", "~760 kcal \u{00b7} Dinner", "Chicken Thighs + Brown Rice + Roasted Zucchini", "2 chicken thighs, pan-roasted. \u{00be} cup brown rice. 1.5 cups roasted zucchini with olive oil. Finish with 2\u{2013}3 squares dark chocolate and chamomile tea. Hearty, filling, zero bloat triggers.", nil, 48, 72, 24)
        // Day 2
        m(ctx, id, 2, "Day 2", "~1,560 kcal", "lunch", "12:00pm", "~580 kcal \u{00b7} Lunch", "Chana Masala-Style Chickpea Bowl", "1 cup chickpeas in tomato-cumin-ginger masala (canned chickpeas + spices, 10 min). \u{00bd} cup brown rice. Sliced cucumber raita on the side. Chickpeas are the best luteal legume \u{2014} high in B6, manganese, and fiber that directly supports progesterone production. This is comfort food as medicine.", "\u{2726} SA note: Chana masala is literally the perfect luteal meal for South Asian women \u{2014} ancestral and hormonal alignment", 30, 70, 14)
        m(ctx, id, 2, "Day 2", "~1,560 kcal", "snack", "3:30pm", "~230 kcal \u{00b7} Snack", "Siggis + Oats + Berries", "\u{00be} cup Siggis, 2 tbsp rolled oats (dry, for texture), \u{00bc} cup blueberries, 1 tsp honey. Oats are a slow-release carb that boosts serotonin \u{2014} one of the best foods for luteal mood and specifically helpful for South Asian blood sugar oscillations.", nil, 16, 28, 6)
        m(ctx, id, 2, "Day 2", "~1,560 kcal", "dinner", "7:00pm", "~750 kcal \u{00b7} Dinner", "Salmon + Roasted Sweet Potato + Saut\u{00e9}ed Kale", "5oz roasted salmon. 1 medium sweet potato. 2 cups saut\u{00e9}ed kale with garlic and olive oil. Drizzle of tahini. 2\u{2013}3 squares dark chocolate to close. Deeply satisfying, zero bloat foods.", nil, 46, 68, 22)
        // Day 3
        m(ctx, id, 3, "Day 3", "~1,555 kcal", "lunch", "12:00pm", "~570 kcal \u{00b7} Lunch", "Masala Egg Bake + Sourdough", "4 eggs baked with saut\u{00e9}ed onion, garlic, cumin, turmeric, spinach, tomato, and a little feta. 1 slice sourdough. Essentially shakshuka without the pepper base. Eggs are your best tryptophan source \u{2014} converts to serotonin and melatonin, directly addressing the sleep disruption common in luteal.", "\u{2726} SA note: adding turmeric and cumin to eggs turns a basic meal into an anti-inflammatory powerhouse", 36, 34, 26)
        m(ctx, id, 3, "Day 3", "~1,555 kcal", "snack", "3:30pm", "~215 kcal \u{00b7} Snack", "Apple + Nut Butter + Pumpkin Seeds", "1 apple, 1.5 tbsp almond or peanut butter, sprinkle of pumpkin seeds. Keeps blood sugar stable through end-of-workday slump that hits hardest in late luteal for South Asian bodies.", nil, 7, 28, 10)
        m(ctx, id, 3, "Day 3", "~1,555 kcal", "dinner", "7:00pm", "~770 kcal \u{00b7} Dinner", "Red Lentil Dal + Brown Rice + Cucumber Raita", "1.5 cups red lentil dal with coconut milk, turmeric, cumin, garlic, ginger, tomato. \u{00bd} cup brown rice. Cucumber raita. 2\u{2013}3 squares dark chocolate after. Make a big batch \u{2014} eat it two nights. Most comforting, most nourishing luteal dinner in the plan.", nil, 34, 84, 20)
        // Day 4
        m(ctx, id, 4, "Day 4", "~1,545 kcal", "lunch", "12:00pm", "~560 kcal \u{00b7} Lunch", "Turkey Burger Bowl", "5oz turkey burger crumbled over mixed greens, roasted sweet potato cubes, avocado, pickled red onion, Dijon. Hearty enough to feel like a treat, perfectly on plan. Turkey provides tryptophan + B6 for mood support in the second half of luteal.", nil, 44, 42, 22)
        m(ctx, id, 4, "Day 4", "~1,545 kcal", "snack", "3:30pm", "~220 kcal \u{00b7} Snack", "Dark Chocolate Oat Energy Bite (\u{00d7}2)", "Make Sundays: rolled oats + almond butter + honey + mini dark chocolate chips + pumpkin seeds, rolled into balls. 10 min to prep the whole week. Perfectly calibrated for luteal cravings \u{2014} sweet but blood-sugar stable. The South Asian equivalent of mithai that won\u{2019}t derail you.", nil, 7, 26, 10)
        m(ctx, id, 4, "Day 4", "~1,545 kcal", "dinner", "7:00pm", "~765 kcal \u{00b7} Dinner", "Chicken & White Bean Soup + Sourdough", "Rotisserie chicken, white beans, kale, chicken broth, garlic, lemon. Big warm bowl. 1.5 slices sourdough. Most effortless high-protein dinner in the plan \u{2014} perfect for days you want to just exist on the couch. This is comfort eating that heals.", nil, 52, 74, 16)
        // Day 5
        m(ctx, id, 5, "Day 5", "~1,580 kcal", "lunch", "12:00pm", "~590 kcal \u{00b7} Lunch", "Warm Oat Bowl with Egg", "\u{00bd} cup rolled oats cooked with almond milk, topped with 1 soft-boiled egg (yes, on top \u{2014} try it), sliced banana, almond butter swirl, cinnamon, sea salt. Blood sugar stays flat for hours. The ultimate luteal comfort breakfast-as-lunch.", nil, 22, 64, 18)
        m(ctx, id, 5, "Day 5", "~1,580 kcal", "snack", "3:30pm", "~210 kcal \u{00b7} Snack", "Cottage Cheese + Honey + Walnuts", "\u{00bd} cup Good Culture, 1 tsp honey, 1 tbsp walnuts, cinnamon. Walnuts contain melatonin \u{2014} directly useful for the sleep disruption in late luteal.", nil, 16, 14, 10)
        m(ctx, id, 5, "Day 5", "~1,580 kcal", "dinner", "7:00pm", "~780 kcal \u{00b7} Dinner", "Pan-Seared Salmon + Brown Rice + Roasted Carrots", "6oz salmon (slightly bigger tonight \u{2014} you earned it). \u{00be} cup brown rice. 1.5 cups roasted carrots with honey and thyme. Tahini drizzle. 3 squares dark chocolate to close. Satisfying, zero bloat triggers, feels indulgent on a calorie budget.", nil, 52, 74, 24)
    }

    // MARK: - Workouts

    private static func seedWorkouts(into ctx: ModelContext) {
        let monId = UUID().uuidString
        let tueId = UUID().uuidString
        let wedId = UUID().uuidString
        let thuId = UUID().uuidString
        let friId = UUID().uuidString
        let satId = UUID().uuidString
        let sunId = UUID().uuidString

        let workouts = [
            Workout(id: monId, dayOfWeek: 0, dayLabel: "Monday", dayFocus: "Lower Body + Incline Walk", isRestDay: false),
            Workout(id: tueId, dayOfWeek: 1, dayLabel: "Tuesday", dayFocus: "Upper Body + Core", isRestDay: false),
            Workout(id: wedId, dayOfWeek: 2, dayLabel: "Wednesday", dayFocus: "Active Recovery + Long Walk", isRestDay: false),
            Workout(id: thuId, dayOfWeek: 3, dayLabel: "Thursday", dayFocus: "Full Body Strength", isRestDay: false),
            Workout(id: friId, dayOfWeek: 4, dayLabel: "Friday", dayFocus: "Long Walk + Lower Finisher", isRestDay: false),
            Workout(id: satId, dayOfWeek: 5, dayLabel: "Saturday", dayFocus: "Gentle + Meal Prep", isRestDay: false),
            Workout(id: sunId, dayOfWeek: 6, dayLabel: "Sunday", dayFocus: "Rest & Reset", isRestDay: true),
        ]
        workouts.forEach { ctx.insert($0) }

        let sessions = [
            // Monday
            WorkoutSession(workoutId: monId, timeSlot: "9:00am \u{00b7} 20 min", title: "Mobility + Core Protocol.", sessionDescription: "Hip circles, cat-cow, figure-four. Then full daily core sequence."),
            WorkoutSession(workoutId: monId, timeSlot: "10:30am \u{00b7} 20 min", title: "Treadmill incline walk.", sessionDescription: "3.5\u{2013}4mph, incline 6\u{2013}8%. This is your primary fat-burn session. Put on a podcast."),
            WorkoutSession(workoutId: monId, timeSlot: "12:45pm \u{00b7} 12 min", title: "Post-lunch flat walk.", sessionDescription: "3mph, zero pressure. Glucose management."),
            WorkoutSession(workoutId: monId, timeSlot: "4:00pm \u{00b7} 15 min", title: "Lower body finisher.", sessionDescription: "3\u{00d7}15 glute bridges, 3\u{00d7}12 sumo squats, 3\u{00d7}10 reverse lunges. Slow and controlled \u{2014} feel every rep."),
            // Tuesday
            WorkoutSession(workoutId: tueId, timeSlot: "9:00am \u{00b7} 20 min", title: "Shoulder + chest mobility.", sessionDescription: "Thoracic rotations, chest opener, neck release. Then core protocol."),
            WorkoutSession(workoutId: tueId, timeSlot: "10:30am \u{00b7} 20 min", title: "Upper body strength.", sessionDescription: "3\u{00d7}12 push-ups, 3\u{00d7}15 tricep dips on chair, 3\u{00d7}12 bent-over rows (use water jugs / filled bag). 60sec rest between sets."),
            WorkoutSession(workoutId: tueId, timeSlot: "12:45pm \u{00b7} 12 min", title: "Post-lunch walk.", sessionDescription: "Flat, easy."),
            WorkoutSession(workoutId: tueId, timeSlot: "4:00pm \u{00b7} 15 min", title: "Treadmill incline.", sessionDescription: "3.5mph, incline 8\u{2013}10%. High incline, slower pace = maximum glute + core activation without joint stress."),
            // Wednesday
            WorkoutSession(workoutId: wedId, timeSlot: "9:00am \u{00b7} 20 min", title: "Gentle floor stretch.", sessionDescription: "Forward folds, pigeon prep, spinal twist. Core protocol \u{2014} lighter today."),
            WorkoutSession(workoutId: wedId, timeSlot: "10:30am \u{00b7} 25 min", title: "Longer treadmill walk.", sessionDescription: "Flat, 3\u{2013}3.5mph. Podcast or music. This is restorative cardio \u{2014} cumulative fat burning, zero stress on joints or nervous system."),
            WorkoutSession(workoutId: wedId, timeSlot: "12:45pm \u{00b7} 12 min", title: "Post-lunch walk.", sessionDescription: "Flat, easy."),
            WorkoutSession(workoutId: wedId, timeSlot: "4:00pm \u{00b7} 10 min", title: "Standing micro-session.", sessionDescription: "Calf raises 3\u{00d7}20, standing hip abductions 3\u{00d7}15 each side, wall sit 3\u{00d7}30sec. No equipment."),
            // Thursday
            WorkoutSession(workoutId: thuId, timeSlot: "9:00am \u{00b7} 20 min", title: "Full mobility warm-up.", sessionDescription: "Ankle circles, hip flexor stretch, chest opener. Core protocol."),
            WorkoutSession(workoutId: thuId, timeSlot: "10:30am \u{00b7} 20 min", title: "Full body circuit \u{00b7} 3 rounds.", sessionDescription: "Squat to overhead press (water jugs), Romanian deadlift, push-up, reverse lunge. 45sec work / 15sec rest. This is your hardest session of the week."),
            WorkoutSession(workoutId: thuId, timeSlot: "12:45pm \u{00b7} 12 min", title: "Post-lunch walk.", sessionDescription: "Easy, flat \u{2014} you worked hard this morning."),
            WorkoutSession(workoutId: thuId, timeSlot: "4:00pm \u{00b7} 15 min", title: "Treadmill incline walk.", sessionDescription: "3.5mph, incline 6%. Caps the day\u{2019}s calorie burn."),
            // Friday
            WorkoutSession(workoutId: friId, timeSlot: "9:00am \u{00b7} 20 min", title: "Light stretch.", sessionDescription: "End of week \u{2014} body is tired. Be gentle. Core protocol."),
            WorkoutSession(workoutId: friId, timeSlot: "10:30am \u{00b7} 28 min", title: "Interval treadmill walk.", sessionDescription: "5min easy \u{2192} 8min brisk 3.8mph incline 6% \u{2192} 5min easy \u{2192} 5min incline 8% \u{2192} 5min cooldown. Variation prevents adaptation."),
            WorkoutSession(workoutId: friId, timeSlot: "12:45pm \u{00b7} 12 min", title: "Post-lunch walk.", sessionDescription: ""),
            WorkoutSession(workoutId: friId, timeSlot: "4:00pm \u{00b7} 12 min", title: "Lower body finisher.", sessionDescription: "Wall sits 3\u{00d7}40sec, sumo squats 3\u{00d7}15, lateral leg raises 3\u{00d7}12. End of week \u{2014} push through."),
            // Saturday
            WorkoutSession(workoutId: satId, timeSlot: "Morning \u{00b7} 20 min", title: "Yoga if going, or relaxed treadmill walk.", sessionDescription: "No pressure. This is joyful movement day \u{2014} let it be whatever feels good."),
            WorkoutSession(workoutId: satId, timeSlot: "Afternoon", title: "Meal prep.", sessionDescription: "40 min of cooking counts as movement. Batch your grains, roast your proteins and vegetables, prep snacks for the week."),
            WorkoutSession(workoutId: satId, timeSlot: "Optional", title: "10-min core protocol", sessionDescription: "if you feel like it. Never mandatory on weekends."),
            // Sunday
            WorkoutSession(workoutId: sunId, timeSlot: "Evening \u{00b7} 10 min", title: "Gentle stretch only.", sessionDescription: "Legs up the wall, spinal twist, forward fold. Let your body repair. Rest is where toning actually happens."),
        ]
        sessions.forEach { ctx.insert($0) }

        let exercises = [
            CoreExercise(name: "Dead Bug", exerciseDescription: "Lie on back, arms up, knees 90\u{00b0}. Lower opposite arm/leg toward floor simultaneously, keeping lower back pressed down. The transverse abdominis is doing all the work \u{2014} you\u{2019}ll feel it deeply.", sets: "3 \u{00d7} 10 reps each side"),
            CoreExercise(name: "Bird Dog", exerciseDescription: "On all fours, extend opposite arm and leg. Hold 2 seconds at extension. Builds deep spinal stability and oblique strength. Excellent for posture which makes your stomach look flatter immediately.", sets: "3 \u{00d7} 10 reps each side"),
            CoreExercise(name: "Plank Hold", exerciseDescription: "Forearms or hands. Squeeze glutes, tuck pelvis slightly, breathe normally. Don\u{2019}t let hips sag or pike. Start at 20 seconds \u{2014} add 5 seconds each week as it becomes easier.", sets: "3 \u{00d7} 20\u{2013}40 sec holds"),
            CoreExercise(name: "Hollow Body Hold", exerciseDescription: "Lie on back, arms overhead, lower back pressed flat, legs straight and raised 6\u{2013}12 inches. This is the single most effective transverse abdominis exercise. Hard at first \u{2014} that means it\u{2019}s working.", sets: "2 \u{00d7} 15 sec, build to 30 sec"),
            CoreExercise(name: "Side Plank Hip Dips", exerciseDescription: "Side plank position, lower hip toward floor and raise back up. Directly targets the obliques and the lateral fat that spills over waistbands. The move that creates an actual waist definition.", sets: "2 \u{00d7} 10 each side"),
            CoreExercise(name: "Glute Bridge March", exerciseDescription: "In glute bridge position, alternate lifting one knee toward chest while holding the bridge. Works core and glutes simultaneously \u{2014} addresses the posterior chain weakness that\u{2019}s contributing to your knee pain.", sets: "2 \u{00d7} 10 each side"),
        ]
        exercises.forEach { ctx.insert($0) }
    }

    // MARK: - Groceries

    private static func seedGroceries(into ctx: ModelContext, menstrualId mId: String, follicularId fId: String, ovulatoryId oId: String, lutealId lId: String) {
        func g(_ phaseId: String, _ cat: String, _ name: String, _ sa: String? = nil) {
            ctx.insert(GroceryItem(phaseId: phaseId, category: cat, name: name, saFlag: sa))
        }

        // Menstrual
        g(mId, "Protein", "Salmon fillets (2 lbs)")
        g(mId, "Protein", "Chicken thighs, bone-in (4)")
        g(mId, "Protein", "Rotisserie chicken (1 whole)")
        g(mId, "Protein", "Grass-fed sirloin or flank (4oz)")
        g(mId, "Protein", "Lean ground beef 93% (\u{00bd} lb)")
        g(mId, "Protein", "Eggs (1 dozen)")
        g(mId, "Protein", "Siggis plain yogurt (3 cups)")
        g(mId, "Protein", "Cottage cheese, Good Culture (1)")
        g(mId, "Produce", "Baby spinach (2 large bags)")
        g(mId, "Produce", "Beets (4\u{2013}5, or pre-roasted pkg)")
        g(mId, "Produce", "Kale (1 bunch)")
        g(mId, "Produce", "Carrots (1 lb)")
        g(mId, "Produce", "Sweet potatoes (3 medium)")
        g(mId, "Produce", "Red bell peppers (3)")
        g(mId, "Produce", "Cremini mushrooms (1 pack)")
        g(mId, "Produce", "Broccoli (1 head)")
        g(mId, "Produce", "Blueberries or raspberries (1 pint)")
        g(mId, "Produce", "Apples (3)")
        g(mId, "Produce", "Avocados (2)")
        g(mId, "Produce", "Lemons (5)")
        g(mId, "Produce", "Fresh ginger (1 knob)")
        g(mId, "Produce", "Yukon gold potatoes (1 lb)")
        g(mId, "Pantry / Grains", "Red lentils / masoor dal", "\u{2726}")
        g(mId, "Pantry / Grains", "Kidney beans, canned (rajma)", "\u{2726}")
        g(mId, "Pantry / Grains", "White beans, canned (1 can)")
        g(mId, "Pantry / Grains", "Brown rice (bag or microwavable)", "\u{2726}")
        g(mId, "Pantry / Grains", "Sourdough bread (1 loaf)")
        g(mId, "Pantry / Grains", "Bone broth, Kettle & Fire (2 cartons)")
        g(mId, "Pantry / Grains", "Chicken broth (1 carton)")
        g(mId, "Pantry / Grains", "Diced tomatoes, canned (2 cans)")
        g(mId, "Pantry / Grains", "Coconut milk, canned (1 can)")
        g(mId, "Pantry / Grains", "Tahini (jar)")
        g(mId, "Pantry / Grains", "Almond butter (jar)")
        g(mId, "Pantry / Grains", "Pumpkin seeds")
        g(mId, "Pantry / Grains", "Walnuts")
        g(mId, "Pantry / Grains", "Dark chocolate 85%+ (Lindt / Hu)")
        g(mId, "Pantry / Grains", "Ground turmeric", "\u{2726}")
        g(mId, "Pantry / Grains", "Cumin seeds + ground cumin", "\u{2726}")
        g(mId, "Pantry / Grains", "Balsamic vinegar")
        g(mId, "Pantry / Grains", "Sesame oil")
        g(mId, "Pantry / Grains", "Soy sauce / tamari")

        // Follicular
        g(fId, "Protein", "Chicken breasts (2 lbs)")
        g(fId, "Protein", "Ground turkey (1 lb)")
        g(fId, "Protein", "Salmon fillets (1 lb)")
        g(fId, "Protein", "Wild tuna in olive oil (2 cans)")
        g(fId, "Protein", "Eggs (1 dozen)")
        g(fId, "Protein", "Siggis plain yogurt (2 cups)")
        g(fId, "Protein", "Cottage cheese Good Culture (1)")
        g(fId, "Protein", "Edamame, frozen shelled (1 bag)")
        g(fId, "Produce", "Mixed greens + arugula (2 bags)")
        g(fId, "Produce", "Broccoli (2 heads)", "\u{2726} DIM")
        g(fId, "Produce", "Asparagus (1 bunch)")
        g(fId, "Produce", "Cherry tomatoes (2 pints)")
        g(fId, "Produce", "Bok choy or snap peas (1 bag)")
        g(fId, "Produce", "Purple cabbage (small head)")
        g(fId, "Produce", "Cucumber (2), Zucchini (3)")
        g(fId, "Produce", "Bell peppers (3 mixed)")
        g(fId, "Produce", "Avocados (3)")
        g(fId, "Produce", "Blueberries (1 pint), Kiwi (2)")
        g(fId, "Produce", "Apples (3), Lemons + Limes (6)")
        g(fId, "Produce", "Sweet potato (1 medium)")
        g(fId, "Produce", "Shallots + Scallions")
        g(fId, "Pantry / Grains", "Soba noodles (1 pack)", "\u{2726}")
        g(fId, "Pantry / Grains", "Brown rice or farro", "\u{2726}")
        g(fId, "Pantry / Grains", "Quinoa")
        g(fId, "Pantry / Grains", "Ground flaxseed (bag)", "\u{2726} daily")
        g(fId, "Pantry / Grains", "Sauerkraut (jar, refrigerated)", "\u{2726}")
        g(fId, "Pantry / Grains", "Kalamata olives + Capers (jars)")
        g(fId, "Pantry / Grains", "Dijon mustard")
        g(fId, "Pantry / Grains", "Tamari or soy sauce")
        g(fId, "Pantry / Grains", "Black beans, canned (1 can)")
        g(fId, "Pantry / Grains", "Tahini, Almond butter")
        g(fId, "Pantry / Grains", "Pumpkin seeds")
        g(fId, "Pantry / Grains", "Pickled red onion (jar)")

        // Ovulatory
        g(oId, "Protein", "Chicken breasts (1 lb)")
        g(oId, "Protein", "Ground turkey (1 lb)")
        g(oId, "Protein", "Salmon (1 lb)")
        g(oId, "Protein", "Ahi / wild tuna, canned (2 cans)")
        g(oId, "Protein", "Sardines in olive oil (2 tins)")
        g(oId, "Protein", "Deli turkey slices (\u{00bd} lb)")
        g(oId, "Protein", "Siggis plain yogurt (2 cups)")
        g(oId, "Protein", "Edamame, frozen (1 bag)")
        g(oId, "Produce", "Mixed greens (2 bags)")
        g(oId, "Produce", "Romaine hearts (taco cups)")
        g(oId, "Produce", "Asparagus (1 bunch)", "\u{2726} priority")
        g(oId, "Produce", "Fennel (1 bulb)")
        g(oId, "Produce", "Purple cabbage (small head)")
        g(oId, "Produce", "Cucumber (2), Bell peppers (2)")
        g(oId, "Produce", "Avocados (3)")
        g(oId, "Produce", "Orange or grapefruit (2)")
        g(oId, "Produce", "Bananas (3)", "\u{2726} B6")
        g(oId, "Produce", "Mixed berries (1 pint)")
        g(oId, "Produce", "Lemons + limes (4)")
        g(oId, "Produce", "Scallions, fresh parsley")
        g(oId, "Produce", "Pico de gallo, premade")
        g(oId, "Pantry / Grains", "Brown rice")
        g(oId, "Pantry / Grains", "Farro (small bag)")
        g(oId, "Pantry / Grains", "Hummus (container)")
        g(oId, "Pantry / Grains", "Pumpkin seeds", "\u{2726} zinc")
        g(oId, "Pantry / Grains", "Almonds, Goat cheese crumbles")
        g(oId, "Pantry / Grains", "Almond butter")
        g(oId, "Pantry / Grains", "Sesame oil, Tamari")
        g(oId, "Pantry / Grains", "Ground cumin + chili powder")

        // Luteal
        g(lId, "Protein", "Rotisserie chicken (1\u{2013}2 whole)")
        g(lId, "Protein", "Chicken thighs, bone-in (4)")
        g(lId, "Protein", "Ground turkey (1 lb)")
        g(lId, "Protein", "Salmon fillets (1.5 lbs)")
        g(lId, "Protein", "Eggs (1 dozen)")
        g(lId, "Protein", "Siggis plain yogurt (3 cups)")
        g(lId, "Protein", "Cottage cheese Good Culture (2)")
        g(lId, "Protein", "Feta cheese (small block)")
        g(lId, "Produce", "Sweet potatoes (5 medium)", "\u{2726} priority")
        g(lId, "Produce", "Baby spinach / kale (2 large bags)")
        g(lId, "Produce", "Arugula (1 bag)")
        g(lId, "Produce", "Zucchini (3), Carrots (1 lb)")
        g(lId, "Produce", "Cremini mushrooms (1 pack)")
        g(lId, "Produce", "Red bell peppers (3)")
        g(lId, "Produce", "Cucumber (2), Avocados (3)")
        g(lId, "Produce", "Bananas (5\u{2013}6)", "\u{2726} B6")
        g(lId, "Produce", "Apples (3), Blueberries (1 pint)")
        g(lId, "Produce", "Lemons (4)")
        g(lId, "Produce", "Diced tomatoes, canned (2 cans)")
        g(lId, "Produce", "Onions (2), Garlic (1 head)")
        g(lId, "Pantry / Grains", "Rolled oats (container)", "\u{2726}")
        g(lId, "Pantry / Grains", "Brown rice (bag or microwavable)", "\u{2726}")
        g(lId, "Pantry / Grains", "Red lentils / masoor dal", "\u{2726}")
        g(lId, "Pantry / Grains", "Chickpeas, canned (3 cans)", "\u{2726}")
        g(lId, "Pantry / Grains", "White beans, canned (2 cans)")
        g(lId, "Pantry / Grains", "Sourdough bread (1 loaf)")
        g(lId, "Pantry / Grains", "Coconut milk, canned (2 cans)")
        g(lId, "Pantry / Grains", "Chicken broth (2 cartons)")
        g(lId, "Pantry / Grains", "Almond milk (carton)")
        g(lId, "Pantry / Grains", "Tahini, Almond butter")
        g(lId, "Pantry / Grains", "Dark chocolate 85%+ (3 bars)", "\u{2726} daily")
        g(lId, "Pantry / Grains", "Mini dark choc chips (small bag)")
        g(lId, "Pantry / Grains", "Pumpkin seeds, Walnuts")
        g(lId, "Pantry / Grains", "Ground turmeric + cumin", "\u{2726}")
        g(lId, "Pantry / Grains", "Chamomile tea (box)")
        g(lId, "Pantry / Grains", "Honey, Pickled red onion (jar)")
        g(lId, "Pantry / Grains", "Cinnamon", "\u{2726} anti-inflammatory SA")
    }

    // MARK: - Phase Reminders

    private static func seedReminders(into ctx: ModelContext, menstrualId mId: String, follicularId fId: String, ovulatoryId oId: String, lutealId lId: String) {
        func r(_ phaseId: String, _ icon: String, _ text: String, _ level: String? = nil) {
            ctx.insert(PhaseReminder(phaseId: phaseId, icon: icon, text: text, evidenceLevel: level))
        }

        // Menstrual
        r(mId, "\u{1fa78}", "Iron-rich foods are essential \u{2014} menstrual blood loss averages 15\u{2013}30 mg of iron per cycle. Pair iron sources with vitamin C to double absorption. Avoid tea and coffee within an hour of iron-rich meals.", "strong")
        r(mId, "\u{1f41f}", "Omega-3 fatty acids (300\u{2013}1,800 mg EPA+DHA daily) significantly reduce menstrual cramps by lowering pro-inflammatory prostaglandins \u{2014} the compounds driving cramping. Multiple meta-analyses confirm a large effect.", "strong")
        r(mId, "\u{1f48a}", "Calcium (1,000\u{2013}1,200 mg/day) reduces overall PMS and menstrual symptoms by up to 48% when taken consistently over 2\u{2013}3 months. Start now \u{2014} the benefit is cumulative.", "strong")
        r(mId, "\u{1f9d8}", "You can train at any intensity if you feel well. Research shows no meaningful performance reduction during menstruation. Adjust to how your body feels, not a calendar. Yoga, walks, or full sessions are all valid.", "strong")
        r(mId, "\u{1f321}\u{fe0f}", "Menstrual cramps are driven by prostaglandin F2\u{03b1} contracting the uterus. Anti-inflammatory foods \u{2014} ginger, turmeric, oily fish \u{2014} may ease discomfort alongside NSAIDs.", "moderate")
        r(mId, "\u{1f4a7}", "2.5L water daily + electrolytes. A pinch of Himalayan salt in water with lemon supports hydration when bleeding. Avoid excess caffeine \u{2014} it depletes iron and can worsen cramps.", "moderate")

        // Follicular
        r(fId, "\u{26a1}", "Rising estradiol directly boosts serotonin and dopamine synthesis. Most women feel increased energy, motivation, and sociability during this phase \u{2014} this is well-documented neurochemistry, not coincidence.", "strong")
        r(fId, "\u{1f3c3}", "Many women feel their best physically in the follicular phase. Research on whether this phase produces measurably superior performance is mixed \u{2014} train at whatever intensity matches your energy, not because a schedule says to.", "moderate")
        r(fId, "\u{1f957}", "Insulin sensitivity is typically higher in the follicular phase (HOMA-IR ~1.35 vs ~1.59 in luteal per BioCycle Study). Your body handles carbohydrates more efficiently now.", "moderate")
        r(fId, "\u{1f331}", "Seed cycling (follicular phase: flaxseed + pumpkin seeds) is a popular wellness practice believed to support estrogen balance through lignans and zinc. No clinical trials have tested it \u{2014} anecdotal evidence only. Many find it a meaningful daily ritual.", "expert_opinion")
        r(fId, "\u{1fad9}", "One fermented food daily (yogurt, kefir, lassi) supports gut microbiome health, which influences estrogen metabolism via the estrobolome. Mechanistically sound \u{2014} direct human RCT evidence for cycle effects is limited.", "emerging")

        // Ovulatory
        r(oId, "\u{1f321}\u{fe0f}", "Your basal body temperature rises 0.3\u{2013}0.5\u{00b0}C after ovulation \u{2014} the most reliable physical sign ovulation has occurred. If tracking BBT, look for this sustained shift.", "strong")
        r(oId, "\u{26a1}", "Peak estradiol and a mid-cycle testosterone rise create the highest energy and libido of the cycle for most women. This is a real hormonal effect, not placebo.", "strong")
        r(oId, "\u{1f4a7}", "About 20% of women experience mittelschmerz \u{2014} mild one-sided pelvic pain from follicle rupture, lasting hours to a day. It is harmless and self-resolving.", "strong")
        r(oId, "\u{1f6ab}", "Avoid alcohol this phase \u{2014} peak estradiol combined with alcohol amplifies estrogenic effects and can worsen the luteal transition. Sparkling water with citrus instead.", "moderate")

        // Luteal
        r(lId, "\u{1f321}\u{fe0f}", "Core body temperature is measurably 0.3\u{2013}0.7\u{00b0}C higher in the luteal phase due to progesterone \u{2014} decades of replicated data confirm this. In hot or humid conditions, prioritize hydration, pre-cooling, and pacing awareness during exercise.", "strong")
        r(lId, "\u{1f36b}", "Appetite increases 100\u{2013}500 kcal/day in the late luteal phase \u{2014} this is real and driven by progesterone\u{2019}s thermogenic effect. Carbohydrate cravings are likely your body\u{2019}s attempt to boost serotonin via the insulin\u{2192}tryptophan pathway. Dark chocolate (magnesium) and complex carbs are legitimate responses.", "strong")
        r(lId, "\u{1f634}", "Progesterone\u{2019}s calming metabolite (allopregnanolone) acts on GABA-A receptors \u{2014} you may feel calmer but sleepier in the early luteal phase. As both hormones drop in the late luteal, mood instability can increase. This is neurochemistry, not character.", "strong")
        r(lId, "\u{1f3cb}\u{fe0f}", "Many practitioners recommend listening to your body more closely in the luteal phase. Note: muscle protein synthesis is identical to the follicular phase (Colenso-Semple 2025, Journal of Physiology). You do not need to avoid strength training \u{2014} but heat management matters more now.", "moderate")
        r(lId, "\u{1f48a}", "Magnesium (200 mg) + Vitamin B6 (50 mg) showed the strongest supplement results for PMS symptoms in clinical studies. Evening magnesium may also support sleep quality in the late luteal phase.", "moderate")
        r(lId, "\u{1f331}", "Seed cycling (luteal phase: sesame + sunflower seeds) is believed to support progesterone metabolism via zinc and selenium. No clinical trials to date \u{2014} anecdotal evidence only. If it feels good, there\u{2019}s no harm in continuing.", "expert_opinion")
        r(lId, "\u{1f9c2}", "Watch sodium \u{2014} you retain water more easily now due to aldosterone-mediated fluid shifts. Avoid high-sodium processed or restaurant food if you are already feeling puffy. You are not gaining fat.", "moderate")
    }

    // MARK: - Phase Nutrients

    private static func seedNutrients(into ctx: ModelContext, menstrualId mId: String, follicularId fId: String, ovulatoryId oId: String, lutealId lId: String) {
        func n(_ phaseId: String, _ icon: String, _ label: String) {
            ctx.insert(PhaseNutrient(phaseId: phaseId, icon: icon, label: label))
        }

        // Menstrual
        n(mId, "\u{1f534}", "Iron (red meat, lentils, spinach)")
        n(mId, "\u{1f41f}", "Omega-3 (salmon, walnuts)")
        n(mId, "\u{1f33f}", "Turmeric + Ginger (anti-cramp)")
        n(mId, "\u{1f36b}", "Magnesium (dark choc, pumpkin seeds)")
        n(mId, "\u{1f34b}", "Vitamin C with iron (lemon, bell pepper)")

        // Follicular
        n(fId, "\u{1f957}", "Flaxseed (estrogen metabolism)")
        n(fId, "\u{1f952}", "Fermented foods (gut-estrogen axis)")
        n(fId, "\u{1fab0}", "Antioxidants (cellular repair)")
        n(fId, "\u{1f966}", "Cruciferous veg (estrogen detox / DIM)")
        n(fId, "\u{1f41f}", "Lean protein (muscle building)")

        // Ovulatory
        n(oId, "\u{1f33b}", "Zinc (pumpkin seeds, turkey)")
        n(oId, "\u{1f41f}", "Omega-3 (salmon, sardines)")
        n(oId, "\u{1f966}", "Fiber (estrogen clearing)")
        n(oId, "\u{1f34c}", "Vitamin B6 (turkey, banana \u{2014} preps for luteal)")
        n(oId, "\u{1f951}", "Healthy fats (hormone production)")

        // Luteal
        n(lId, "\u{1f360}", "Complex carbs (blood sugar stability)")
        n(lId, "\u{1f36b}", "Magnesium (dark choc, seeds, greens)")
        n(lId, "\u{1fab8}", "Fiber (hormone waste removal)")
        n(lId, "\u{1f414}", "Tryptophan (turkey, eggs \u{2192} serotonin)")
        n(lId, "\u{2615}", "Limit caffeine (worsens anxiety + bloating)")

        // ── Supplements ──────────────────────────────────────────────

        func sup(
            _ name: String, brand: String? = nil, cat: String,
            size: Int = 1, unit: String = "capsule",
            nutrients: [(String, Double, String)] = []
        ) {
            let def = SupplementDefinition(
                name: name, brand: brand, category: cat,
                servingSize: size, servingUnit: unit
            )
            ctx.insert(def)
            for (key, amt, u) in nutrients {
                ctx.insert(SupplementNutrient(supplementId: def.id, nutrientKey: key, amount: amt, unit: u))
            }
        }

        sup("Vitamin D3", brand: "NatureWise", cat: "Vitamins", unit: "softgel",
            nutrients: [("vitaminD3", 2000, "IU")])
        sup("Magnesium Glycinate", brand: "Doctor's Best", cat: "Minerals",
            nutrients: [("magnesium", 200, "mg")])
        sup("Omega-3 Fish Oil", brand: "Nordic Naturals", cat: "Omega / Fatty Acids", unit: "softgel",
            nutrients: [("omega3EPA", 425, "mg"), ("omega3DHA", 250, "mg")])
        sup("Iron Bisglycinate", brand: "Thorne", cat: "Minerals",
            nutrients: [("iron", 25, "mg")])
        sup("Calcium + K2", brand: "Solaray", cat: "Minerals",
            nutrients: [("calcium", 500, "mg"), ("vitaminK2", 50, "mcg")])
        sup("Vitamin B6", brand: "Pure Encapsulations", cat: "Vitamins",
            nutrients: [("vitaminB6", 50, "mg")])
        sup("Vitamin B12", brand: "Jarrow", cat: "Vitamins", unit: "lozenge",
            nutrients: [("vitaminB12", 1000, "mcg")])
        sup("Zinc Picolinate", brand: "Thorne", cat: "Minerals",
            nutrients: [("zinc", 15, "mg")])
        sup("Evening Primrose Oil", brand: "NOW Foods", cat: "Omega / Fatty Acids", unit: "softgel",
            nutrients: [("gla", 135, "mg")])
        sup("Probiotic 50B", brand: "Garden of Life", cat: "Probiotics",
            nutrients: [("probiotics", 50, "B CFU")])
        sup("Ashwagandha KSM-66", brand: "Nootropics Depot", cat: "Herbal",
            nutrients: [("ashwagandha", 600, "mg")])
        sup("DIM + Broccoli Extract", brand: "Smoky Mountain", cat: "Herbal",
            nutrients: [("dim", 200, "mg")])
    }
}
