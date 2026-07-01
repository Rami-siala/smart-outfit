from types import SimpleNamespace

from services.ai_generation_service import (
    EDIT_IMAGE_PROMPT,
    build_edit_image_prompt,
    build_wardrobe_prompt_block,
    build_subtype_negative_prompt,
    infer_item_subtype_from_name,
    _extract_image_api_url,
    _ordered_reference_items,
    resolve_item_subtype,
    serialize_wardrobe_item_detail,
    _select_matching_wardrobe_outfit,
)


def _item(**kwargs):
    defaults = {
        "name": "",
        "type": "",
        "item_subtype": None,
        "category": "",
        "color": None,
        "material": None,
        "season": None,
        "precipitation_resistant": False,
        "ai_detected_metadata": None,
    }
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


def test_infer_item_subtype_from_name_uses_backup_keywords():
    assert infer_item_subtype_from_name("summer shorts", "bottom") == "shorts"
    assert infer_item_subtype_from_name("classic tshirt", "top") == "t_shirt"
    assert infer_item_subtype_from_name("chemise noir", "top") == "dress_shirt"
    assert infer_item_subtype_from_name("black dress shirt", "top") == "dress_shirt"
    assert infer_item_subtype_from_name("black triko", "top") == "sweater"
    assert infer_item_subtype_from_name("leather sac", "accessory") == "bag"


def test_resolve_item_subtype_prefers_explicit_subtype():
    item = _item(
        name="oversized hoodie",
        type="top",
        item_subtype="t_shirt",
    )

    assert resolve_item_subtype(item) == "t_shirt"


def test_build_wardrobe_prompt_block_includes_subtype_priority_rules():
    prompt_block = build_wardrobe_prompt_block(
        {
            "selected_wardrobe_items": [
                _item(
                    name="blue shorts",
                    type="bottom",
                    category="casual",
                    color="blue",
                    season="summer",
                ),
                _item(
                    name="crossbody bag",
                    type="accessory",
                    category="casual",
                    color="black",
                ),
            ]
        }
    )

    assert "subtype shorts" in prompt_block
    assert "Subtype is stronger than generic type" in prompt_block
    assert "never generate long pants" in prompt_block
    assert "visible bag must appear" in prompt_block


def test_build_wardrobe_prompt_block_adds_explicit_visual_subtype_instructions():
    prompt_block = build_wardrobe_prompt_block(
        {
            "selected_wardrobe_items": [
                _item(
                    name="T Shirt Black Sport",
                    type="top",
                    item_subtype="t_shirt",
                    category="sport",
                    color="black",
                    season="summer",
                ),
                _item(
                    name="Short Sport Black",
                    type="bottom",
                    item_subtype="shorts",
                    category="sport",
                    color="black",
                    season="summer",
                ),
                _item(
                    name="Sneaker Sport Black",
                    type="shoe",
                    item_subtype="sneakers",
                    category="sport",
                    color="black",
                    season="summer",
                ),
                _item(
                    name="Chapeau Noir",
                    type="accessory",
                    item_subtype="hat",
                    category="sport",
                    color="black",
                    season="summer",
                ),
            ]
        }
    )

    assert "Top: Wear a black short-sleeve sport T-shirt" in prompt_block
    assert "Do not generate a hoodie, sweatshirt, sweater, jacket, coat, or long-sleeve top" in prompt_block
    assert "Bottom: Wear black sport shorts above the knee" in prompt_block
    assert "Legs below the knee must be visible" in prompt_block
    assert "Do not generate joggers, pants, trousers, jeans, or leggings" in prompt_block
    assert "Shoes: Wear visible black sport athletic sneakers" in prompt_block
    assert "Accessory: Wear a visible black sport hat or cap on the head" in prompt_block
    assert "The selected wardrobe items are mandatory" in prompt_block
    assert "Style may influence aesthetic only and must not change the selected subtype" in prompt_block


def test_build_wardrobe_prompt_block_keeps_shirt_identity_from_item_name():
    prompt_block = build_wardrobe_prompt_block(
        {
            "selected_wardrobe_items": [
                _item(
                    name="chemise noir",
                    type="top",
                    category="chic",
                    color="black",
                    season="all_season",
                ),
            ]
        }
    )

    assert 'selected item name "chemise noir"' in prompt_block
    assert "must remain a tailored dress shirt or button-up silhouette" in prompt_block
    assert "Do not generate a T-shirt, hoodie, sweatshirt, sweater, or casual knit top" in prompt_block


def test_build_wardrobe_prompt_block_forces_chemise_details():
    prompt_block = build_wardrobe_prompt_block(
        {
            "selected_wardrobe_items": [
                _item(
                    name="chemise chic black",
                    type="top",
                    item_subtype="dress_shirt",
                    category="chic",
                    color="black",
                ),
            ]
        }
    )

    assert "visible collar" in prompt_block
    assert "front buttons" in prompt_block
    assert "long sleeves" in prompt_block
    assert "shirt cuffs" in prompt_block
    assert "short-sleeve shirt" in prompt_block


def test_build_subtype_negative_prompt_adds_strict_forbidden_terms():
    negative_prompt = build_subtype_negative_prompt(
        [
            _item(type="top", item_subtype="t_shirt"),
            _item(type="bottom", item_subtype="shorts"),
            _item(type="shoe", item_subtype="sneakers"),
            _item(type="accessory", item_subtype="hat"),
        ]
    )

    assert "hoodie" in negative_prompt
    assert "sweatshirt" in negative_prompt
    assert "long sleeve top" in negative_prompt
    assert "joggers" in negative_prompt
    assert "trousers" in negative_prompt
    assert "jeans" in negative_prompt
    assert "missing hat" in negative_prompt
    assert "no hat" in negative_prompt


def test_serialize_wardrobe_item_detail_returns_structured_item_metadata():
    detail = serialize_wardrobe_item_detail(
        _item(
            id=42,
            name="Black Hoodie",
            type="top",
            item_subtype="hoodie",
            category="sport",
            color="black",
            material="cotton",
            season="winter",
            image_url="https://example.com/hoodie.png",
            visual_description="Black oversized hoodie",
            precipitation_resistant=True,
        )
    )

    assert detail == {
        "id": "42",
        "name": "Black Hoodie",
        "type": "top",
        "itemSubtype": "hoodie",
        "category": "sport",
        "color": "black",
        "material": "cotton",
        "season": "winter",
        "imageUrl": "https://example.com/hoodie.png",
        "visualDescription": "Black oversized hoodie",
        "precipitationResistant": True,
        "wardrobeMatched": True,
        "summary": (
            "Black Hoodie, subtype hoodie, type top, style/category sport, "
            "color black, material cotton, season winter, rain resistant"
        ),
    }


def test_select_matching_wardrobe_outfit_keeps_summer_sport_items_in_mild_weather():
    wardrobe_items = [
        _item(
            name="black t shirt",
            type="top",
            item_subtype="t_shirt",
            category="sport",
            color="black",
            season="summer",
        ),
        _item(
            name="black shorts",
            type="bottom",
            item_subtype="shorts",
            category="sport",
            color="black",
            season="summer",
        ),
        _item(
            name="black sneakers",
            type="shoe",
            item_subtype="sneakers",
            category="sport",
            color="black",
            season="summer",
        ),
        _item(
            name="black bag",
            type="accessory",
            item_subtype="bag",
            category="sport",
            color="black",
            season="summer",
        ),
    ]

    selected_items, warning = _select_matching_wardrobe_outfit(
        wardrobe_items,
        {
            "style": "Sport",
            "color": "black",
            "temperature_value": 23.5,
            "weather_label": "sunny",
            "weather": "sunny",
            "precipitation": "No",
        },
    )

    assert warning is None
    assert len(selected_items) >= 3
    selected_names = {item.name for item in selected_items}
    assert "black t shirt" in selected_names
    assert "black shorts" in selected_names
    assert "black sneakers" in selected_names


def test_select_matching_wardrobe_outfit_prefers_requested_color_for_main_pieces():
    wardrobe_items = [
        _item(
            name="black chic shirt",
            type="top",
            item_subtype="shirt",
            category="chic",
            color="black",
            season="all_season",
        ),
        _item(
            name="white chic shirt",
            type="top",
            item_subtype="shirt",
            category="chic",
            color="white",
            season="all_season",
        ),
        _item(
            name="black chic trousers",
            type="bottom",
            item_subtype="trousers",
            category="chic",
            color="black",
            season="all_season",
        ),
        _item(
            name="beige chic trousers",
            type="bottom",
            item_subtype="trousers",
            category="chic",
            color="beige",
            season="all_season",
        ),
    ]

    selected_items, warning = _select_matching_wardrobe_outfit(
        wardrobe_items,
        {
            "style": "Chic",
            "color": "black",
            "temperature_value": 17.4,
            "weather_label": "sunny",
            "weather": "sunny",
            "precipitation": "No",
        },
    )

    assert warning == "No matching shoes found in your wardrobe — the AI will suggest appropriate footwear."
    assert {item.name for item in selected_items} == {
        "black chic shirt",
        "black chic trousers",
    }


def test_select_matching_wardrobe_outfit_does_not_auto_add_accessory():
    wardrobe_items = [
        _item(
            name="black chic shirt",
            type="top",
            item_subtype="shirt",
            category="chic",
            color="black",
            season="all_season",
        ),
        _item(
            name="black chic trousers",
            type="bottom",
            item_subtype="trousers",
            category="chic",
            color="black",
            season="all_season",
        ),
        _item(
            name="black bag",
            type="accessory",
            item_subtype="bag",
            category="chic",
            color="black",
            season="all_season",
        ),
    ]

    selected_items, _warning = _select_matching_wardrobe_outfit(
        wardrobe_items,
        {
            "style": "Chic",
            "color": "black",
            "temperature_value": 17.4,
            "weather_label": "sunny",
            "weather": "sunny",
            "precipitation": "No",
        },
    )

    assert [item.type for item in selected_items] == ["top", "bottom"]


def test_ordered_reference_items_uses_required_right_side_order():
    ordered = _ordered_reference_items(
        [
            _item(name="coat", type="outwear"),
            _item(name="watch", type="accessory"),
            _item(name="shoe", type="shoe"),
            _item(name="shirt", type="top"),
            _item(name="pants", type="bottom"),
        ]
    )

    assert [item.type for item in ordered] == [
        "top",
        "bottom",
        "shoe",
        "accessory",
        "outwear",
    ]


def test_ordered_reference_items_keeps_first_item_per_type_only():
    ordered = _ordered_reference_items(
        [
            _item(name="first top", type="top"),
            _item(name="second top", type="top"),
            _item(name="shoe", type="shoe"),
        ]
    )

    assert [item.name for item in ordered] == ["first top", "shoe"]


def test_extract_image_api_url_prefers_nested_response_url():
    assert (
        _extract_image_api_url(
            {
                "url": "https://example.com/root.jpg",
                "response": {"url": "https://example.com/nested.jpg"},
            }
        )
        == "https://example.com/nested.jpg"
    )


def test_edit_image_prompt_mentions_exact_selected_items():
    assert "exactly the provided wardrobe items" in EDIT_IMAGE_PROMPT
    assert "Do not invent new clothes" in EDIT_IMAGE_PROMPT


def test_build_edit_image_prompt_keeps_dress_shirt_rules():
    prompt = build_edit_image_prompt(
        {"gender": "man", "skin_tone": "medium"},
        [
            _item(
                name="chemise chic black",
                type="top",
                item_subtype="dress_shirt",
                category="chic",
                color="black",
            ),
            _item(
                name="bottom chic black",
                type="bottom",
                item_subtype="trousers",
                category="chic",
                color="black",
            ),
            _item(
                name="shoe black chic",
                type="shoe",
                item_subtype="sneakers",
                category="chic",
                color="black",
            ),
        ],
    )

    assert "visible collar" in prompt
    assert "front button placket" in prompt
    assert "long sleeves" in prompt
    assert "shirt cuffs" in prompt
    assert "Do not turn a selected dress shirt into a T-shirt" in prompt


def test_build_edit_image_prompt_forces_chemise_identity():
    prompt = build_edit_image_prompt(
        {"gender": "man", "skin_tone": "medium"},
        [
            _item(
                name="chemise chic black",
                type="top",
                item_subtype="dress_shirt",
                category="chic",
                color="black",
            ),
            _item(
                name="bottom chic black",
                type="bottom",
                item_subtype="trousers",
                category="chic",
                color="black",
            ),
        ],
    )

    assert "render it specifically as a chemise" in prompt
    assert "visible collar" in prompt
    assert "front button placket" in prompt
    assert "long sleeves" in prompt
    assert "shirt cuffs" in prompt
    assert "short-sleeve casual shirt" in prompt
