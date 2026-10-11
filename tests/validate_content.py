from test_catalog import load_catalog

if __name__ == "__main__":
    definitions, recipes = load_catalog()
    print("Catalog valid:", len(definitions), "definitions;", len(recipes), "recipes")
