mealie crash-looped after the non-root rollout (#872): ingredient-parser-nlp
downloads its NLTK tagger into `/nltk_data` at import, which uid 1000 cannot
create. An emptyDir at that path restores startup.
