#include "ui2.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct { int builds, mode; } TestState;

static ui2_node *build(void *user_data) {
    TestState *state = (TestState *)user_data;
    state->builds++;
    ui2_node *root = ui2_screen(0x123456);
    if (state->mode == 1) return NULL;
    if (state->mode == 2) {
        ui2_add(root, ui2_label("duplicate", "one", 0, 0, 80, 24));
        ui2_add(root, ui2_label("duplicate", "two", 0, 24, 80, 24));
        return root;
    }
    if (state->mode == 3) {
        ui2_node *a = ui2_create(UI2_VIEW, "a", 0, 0, 100, 100);
        ui2_node *b = ui2_create(UI2_VIEW, "b", 0, 0, 100, 100);
        ui2_add(a, b);
        ui2_add(b, a);
        ui2_add(root, a);
        return root;
    }
    if (state->mode == 4) {
        assert(ui2_create(9999, "invalid", 0, 0, 1, 1) == NULL);
        return root;
    }
    if (state->mode == 5) {
        ui2_node *a = ui2_label(NULL, "one", 0, 0, 80, 24);
        ui2_node *b = ui2_label(NULL, "two", 0, 24, 80, 24);
        ui2_set_key(a, "same");
        ui2_set_key(b, "same");
        ui2_add(root, a);
        ui2_add(root, b);
        return root;
    }
    if (state->mode == 6) {
        ui2_config nested = {0};
        nested.build = build;
        assert(ui2_validate(&nested) == -1);
        return root;
    }
    if (state->mode == 7) {
        ui2_node *child = ui2_label(NULL, "one", 0, 0, 80, 24);
        ui2_add(root, child);
        ui2_add(root, child);
        return root;
    }
    if (state->mode == 8) {
        return ui2_label("label", "not a screen", 0, 0, 80, 24);
    }
    if (state->mode == 9) {
        ui2_set_scroll_mode(root, -1);
        return root;
    }

    for (int kind = UI2_VIEW; kind <= UI2_OPENGL; kind++) {
        char id[32];
        snprintf(id, sizeof id, "widget-%d", kind);
        ui2_node *n = ui2_create(kind, id, 0, kind * 30, 180, 24);
        assert(n != NULL);
        ui2_set_text(n, "Hello, 世界 👋");
        ui2_set_key(n, id);
        ui2_set_action(n, id);
        ui2_set_tooltip(n, "A tooltip");
        ui2_set_placeholder(n, "Type here");
        ui2_set_image(n, "image.png");
        ui2_set_checked(n, 1);
        ui2_set_flags(n, UI2_EMIT_CHANGE);
        ui2_box_style box = ui2_default_box_style();
        box.background = 0x2468ab;
        box.radius = 6;
        box.border_color = 0x121212;
        box.border_left = 2;
        ui2_set_box_style(n, &box);
        ui2_text_style text = ui2_default_text_style();
        text.font_family = "Helvetica";
        text.bold = 1;
        ui2_set_text_style(n, &text);
        if (kind == UI2_SCROLL) ui2_set_scroll_mode(n, UI2_SCROLL_BOTH);
        if (kind == UI2_SLIDER) ui2_set_slider(n, 50, 0, 100, 5, 1);
        if (kind == UI2_DROPDOWN) {
            ui2_add_option(n, "one");
            ui2_add_option(n, "two");
        }
        ui2_add(root, n);
    }
    return root;
}

int main(void) {
    assert(ui2_abi_version() == 1);
    assert(ui2_validate(NULL) == -1);
    assert(strstr(ui2_last_error(), "required") != NULL);
    ui2_config config = {0};
    assert(ui2_run(&config) == -1); /* No callback: no window is opened. */
    TestState state = {0};
    config.build = build;
    config.user_data = &state;
    config.width = -1;
    assert(ui2_validate(&config) == -1);
    config.width = 0;
    for (int i = 0; i < 50; i++) assert(ui2_validate(&config) == 0);
    assert(state.builds == 50);
    const char *errors[] = {"", "handles", "duplicate element id", "cycle",
        "unknown widget", "duplicate sibling key", "already running",
        "one parent", "screen", "unknown scroll mode"};
    for (int mode = 1; mode <= 9; mode++) {
        state.mode = mode;
        assert(ui2_validate(&config) == -1);
        assert(strstr(ui2_last_error(), errors[mode]) != NULL);
    }
    state.mode = 0;
    assert(ui2_validate(&config) == 0); /* Errors do not poison later builds. */
    assert(ui2_last_error()[0] == '\0');

    /* Check mounted-state symbols and caller-owned string output without a UI. */
    char text[8] = "dirty";
    assert(ui2_get_text("missing", NULL, 0) == 1);
    assert(ui2_get_text("missing", text, sizeof text) == 1);
    assert(text[0] == '\0');
    text[0] = 'x';
    assert(ui2_get_text("missing", text, 0) == 1);
    assert(text[0] == 'x');
    ui2_update_text("missing", "text");
    ui2_update_checked("missing", 1);
    ui2_update_value("missing", 42);
    assert(ui2_get_checked("missing") == 0);
    assert(ui2_get_value("missing") == 0);
    ui2_focus("missing");
    double x = -1, y = -1;
    ui2_get_scroll("missing", &x, &y);
    assert(x == 0 && y == 0);
    ui2_scroll_to("missing", 12, 34);
    ui2_bounds(&x, &y);
    assert(x > 0 && y > 0);
    ui2_bounds(NULL, NULL);
    ui2_refresh();
    ui2_quit();
    puts("C ABI tests passed");
    return 0;
}
