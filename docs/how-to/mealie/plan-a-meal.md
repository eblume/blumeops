---
title: Plan a Meal
modified: 2026-06-09
last-reviewed: 2026-06-09
tags:
  - how-to
  - mealie
---

# Plan a Meal

Generate a unified cooking timeline for a meal using [[mealie]]'s API. The timeline interleaves steps from multiple recipes so everything finishes at the same time.

## When to Use

The user says something like "Let's plan a meal" or references this card. Default to **dinner for today** unless the user specifies otherwise.

## Prerequisites

- Mealie running at `https://meals.ops.eblu.me`
- API token in 1Password: `op://blumeops/mealie/credential`

## Process

### 1. Check the Meal Planner

Query today's (or the requested date's) meal plan:

```fish
set MEALIE_TOKEN (op read "op://blumeops/mealie/credential")
set DATE (date +%Y-%m-%d)  # or the requested date
curl -sf "https://meals.ops.eblu.me/api/households/mealplans?start_date=$DATE&end_date=$DATE" \
  -H "Authorization: Bearer $MEALIE_TOKEN"
```

**If the plan has recipes:** the user wants a cooking timeline for those dishes. Skip to step 3.

**If the plan is empty (or user asked for a new meal):** pick recipes in step 2.

### 2. Pick a Balanced Meal

Select one recipe from each tag category to build a balanced dinner:

- **protein** — a main dish (chicken, tofu, meatloaf, etc.)
- **carb** — a starch side (potatoes, noodles, bread, rice)
- **vegetable** — a veggie side (salad, roasted veg, brussels sprouts)

Query by tag:

```fish
set SEED (date +%s)

# Get a random protein
curl -sf "https://meals.ops.eblu.me/api/recipes?tags=protein&orderBy=random&paginationSeed=$SEED&perPage=1" \
  -H "Authorization: Bearer $MEALIE_TOKEN"

# Get a random carb
curl -sf "https://meals.ops.eblu.me/api/recipes?tags=carb&orderBy=random&paginationSeed=$SEED&perPage=1" \
  -H "Authorization: Bearer $MEALIE_TOKEN"

# Get a random vegetable
curl -sf "https://meals.ops.eblu.me/api/recipes?tags=vegetable&orderBy=random&paginationSeed=$SEED&perPage=1" \
  -H "Authorization: Bearer $MEALIE_TOKEN"
```

Many recipes are multi-tagged (e.g., "Spicy Chicken Meal Prep with Rice and Beans" has `protein`, `carb`, and `beans`). If the protein pick already covers carb or vegetable, skip that category or offer a lighter side instead. The protein+carb+vegetable split is a rule of thumb for balance, not a rigid requirement — a one-pot meal with all three doesn't need two more sides.

Present the picks to the user and let them swap any out. Once confirmed, optionally add to the meal plan via the API.

### 3. Fetch Full Recipe Data

For each recipe in the meal, fetch the full details (ingredients + instructions + timing):

```fish
curl -sf "https://meals.ops.eblu.me/api/recipes/$SLUG" \
  -H "Authorization: Bearer $MEALIE_TOKEN"
```

Key fields: `recipeIngredient` (structured ingredients), `recipeInstructions` (ordered steps), `prepTime`, `totalTime`, `performTime`.

### 4. Generate the Cooking Timeline

Using the full recipe data, create a unified timeline that interleaves steps from all dishes. The timeline should use **relative time**:

- **T-X** — mise en place, gathering ingredients, prep that happens before active cooking
- **T=0** — the first active cooking step (usually preheating or starting the longest-cook item)
- **T+X** — cooking steps, with concurrent tasks noted

**Guidelines for the timeline:**

- Start with the dish that takes longest (usually the protein)
- Identify natural wait times (oven time, boiling, simmering) and fill them with prep/cooking of other dishes
- Call out the "busy moments" where multiple things need attention
- End with a **mise en place checklist** — everything to gather before T=0
- Use minutes, not clock times (the user decides when to start)

**Example format:**

```
## Dinner Timeline: Turkey Meatloaf + Mashed Potatoes + Roasted Broccoli

### Mise en Place (gather before you start)
- Ground turkey, egg, breadcrumbs, ketchup, ...
- Russet potatoes, butter, milk, ...
- Broccoli, olive oil, ...

### Timeline
| Time | Action |
|------|--------|
| T-10 | Preheat oven to 350°F |
| T-5  | Meatloaf: sauté onion, mix ingredients |
| T=0  | Meatloaf goes in the oven (55 min) |
| T=0  | Potatoes: peel, dice, rinse, start boiling |
| T+15 | Potatoes: should be boiling, cook 6-7 min |
| T+22 | Potatoes: drain, mash with butter/milk. Cover and set aside |
| T+25 | Broccoli: prep florets, toss with oil on sheet pan |
| T+55 | Meatloaf out. Rest 5 min. Crank oven to 400°F |
| T+55 | Broccoli goes in (15 min at 400°F) |
| T+60 | Slice meatloaf |
| T+70 | Broccoli out. Plate everything. Dinner is served. |

### Busy moments
- Around T+20-25: draining potatoes, mashing, and prepping broccoli overlap
```

## Notes

- The user's wife currently handles breakfast and lunch, so default to dinner unless asked otherwise
- Recipes are tagged with `protein`, `carb`, `vegetable`, and `beans` for meal composition
- Recipes are categorized as `Dinner` or `Side` for the built-in Mealie meal planner
- Mealie API docs are at `https://meals.ops.eblu.me/docs`
- Meal plan rules are configured so the random button in Mealie's UI picks from the correct categories

## Related

- [[mealie]] — Recipe manager service reference
- [[ollama]] — LLM backend (future: automated timeline generation)
