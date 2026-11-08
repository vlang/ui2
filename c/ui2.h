#ifndef UI2_H
#define UI2_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ui2_node ui2_node;

typedef enum {
    UI2_SCREEN, UI2_VIEW, UI2_LABEL, UI2_IMAGE, UI2_BUTTON, UI2_CHECKBOX,
    UI2_DROPDOWN, UI2_TEXT_FIELD, UI2_TEXT_AREA, UI2_SCROLL, UI2_SLIDER,
    UI2_SWITCH, UI2_TOGGLE_BUTTON, UI2_OPENGL
} ui2_kind;

typedef enum {
    UI2_SCROLL_VERTICAL, UI2_SCROLL_HORIZONTAL, UI2_SCROLL_BOTH
} ui2_scroll_mode;

typedef enum { UI2_ALIGN_LEFT, UI2_ALIGN_CENTER, UI2_ALIGN_RIGHT } ui2_align;
typedef enum { UI2_VALIGN_TOP, UI2_VALIGN_MIDDLE, UI2_VALIGN_BOTTOM } ui2_valign;

/* Flags are replaced as a group by ui2_set_flags. */
enum {
    UI2_NATIVE = 1u << 0,
    UI2_DISABLED = 1u << 1,
    UI2_HIDDEN = 1u << 2,
    UI2_READONLY = 1u << 3,
    UI2_SECURE = 1u << 4,
    UI2_EMIT_CHANGE = 1u << 5,
    UI2_BUTTON_BEHAVIOR = 1u << 6,
    UI2_CLICKABLE = 1u << 7,
    UI2_DRAGGABLE = 1u << 8,
    UI2_PERSISTENT_SCROLLBARS = 1u << 9
};

/* Colors are 0xRRGGBB. Dimensions use logical pixels. */
typedef struct ui2_box_style {
    uint32_t background;
    double radius;
    int transparent;
    uint32_t border_color;
    double border_left, border_top, border_right, border_bottom;
} ui2_box_style;

typedef struct ui2_text_style {
    uint32_t color;
    double size;
    const char *font_family;
    int bold, italic, underline, strikethrough;
    int align, valign;
    int lines; /* 0 means unlimited lines. */
} ui2_text_style;

/* Build a fresh tree on each call. Handles live only during this callback.
 * All input strings are copied immediately; NULL means an empty string.
 * Event/key/scroll strings are borrowed for the duration of their callback. */
typedef ui2_node *(*ui2_build_fn)(void *user_data);
typedef void (*ui2_event_fn)(void *user_data, const char *id);

typedef struct ui2_config {
    const char *title;
    int width, height; /* 0 selects 800 x 600. */
    ui2_build_fn build;
    ui2_event_fn event; /* Optional. */
    void *user_data;
    ui2_event_fn key; /* Optional normalized keyboard shortcuts. */
    ui2_event_fn scroll; /* Optional scroll element ID. */
} ui2_config;

#ifndef UI2_IMPLEMENTATION

/* Call on the main thread. One window may run at a time. Returns 0 on
 * success, -1 on error; inspect ui2_last_error. Runtime initialization is
 * automatic when the shared library loads. No V headers are needed. */
int ui2_run(const ui2_config *config);
/* Build and validate without opening a window; also useful for binding tests. */
int ui2_validate(const ui2_config *config);
const char *ui2_last_error(void); /* Borrowed until the next API call/build. */
unsigned int ui2_abi_version(void);

/* Tree construction: call only inside build. No manual allocation or free.
 * IDs identify mounted controls; keys identify children across rebuilds. */
ui2_node *ui2_create(int kind, const char *id, double x, double y,
                     double width, double height);
void ui2_add(ui2_node *parent, ui2_node *child);
void ui2_set_text(ui2_node *node, const char *text);
void ui2_set_key(ui2_node *node, const char *key);
void ui2_set_action(ui2_node *node, const char *action);
void ui2_set_tooltip(ui2_node *node, const char *tooltip);
void ui2_set_placeholder(ui2_node *node, const char *placeholder);
void ui2_set_image(ui2_node *node, const char *path);
void ui2_set_box_style(ui2_node *node, const ui2_box_style *style);
void ui2_set_text_style(ui2_node *node, const ui2_text_style *style);
void ui2_set_flags(ui2_node *node, uint32_t flags);
void ui2_set_checked(ui2_node *node, int checked);
void ui2_set_scroll_mode(ui2_node *node, int mode);
void ui2_set_slider(ui2_node *node, double value, double min, double max,
                     double step, int vertical);
void ui2_add_option(ui2_node *node, const char *text);

/* Mounted controls: call on the UI thread, usually from event. Rebuilds
 * preserve local edits when their declared value has not changed. */
void ui2_refresh(void);
void ui2_quit(void);
void ui2_bounds(double *width, double *height);
/* Copies UTF-8 into caller-owned memory, always NUL-terminating if capacity
 * > 0. Returns the required byte count INCLUDING NUL. Query with NULL, 0. */
size_t ui2_get_text(const char *id, char *buffer, size_t capacity);
void ui2_update_text(const char *id, const char *text);
void ui2_focus(const char *id);
double ui2_get_value(const char *id); /* Slider. */
void ui2_update_value(const char *id, double value);
int ui2_get_checked(const char *id); /* Checkbox, switch, toggle button. */
void ui2_update_checked(const char *id, int checked);
void ui2_scroll_to(const char *id, double x, double y);
void ui2_get_scroll(const char *id, double *x, double *y);

/* Convenience constructors use the same exported ABI as ui2_create. */
#ifdef __cplusplus
#define UI2_ZERO_INIT {}
#else
#define UI2_ZERO_INIT {0}
#endif

static inline ui2_node *ui2_screen(uint32_t background) {
    ui2_node *n = ui2_create(UI2_SCREEN, NULL, 0, 0, 0, 0);
    ui2_box_style s = UI2_ZERO_INIT;
    s.background = background;
    ui2_set_box_style(n, &s);
    return n;
}

static inline ui2_node *ui2_label(const char *id, const char *text,
                                 double x, double y, double w, double h) {
    ui2_node *n = ui2_create(UI2_LABEL, id, x, y, w, h);
    ui2_set_text(n, text);
    return n;
}

static inline ui2_node *ui2_button(const char *id, const char *text,
                                  double x, double y, double w, double h) {
    ui2_node *n = ui2_create(UI2_BUTTON, id, x, y, w, h);
    ui2_set_text(n, text);
    ui2_set_flags(n, UI2_NATIVE);
    return n;
}

static inline ui2_node *ui2_scroll(const char *id, int mode,
                                  double x, double y, double w, double h) {
    ui2_node *n = ui2_create(UI2_SCROLL, id, x, y, w, h);
    ui2_set_scroll_mode(n, mode);
    return n;
}

static inline ui2_text_style ui2_default_text_style(void) {
    ui2_text_style s = UI2_ZERO_INIT;
    s.color = 0x111111;
    s.size = 15;
    s.valign = UI2_VALIGN_MIDDLE;
    s.lines = 1;
    return s;
}

static inline ui2_box_style ui2_default_box_style(void) {
    ui2_box_style s = UI2_ZERO_INIT;
    s.background = 0xffffff;
    return s;
}

#undef UI2_ZERO_INIT

#endif /* UI2_IMPLEMENTATION */

#ifdef __cplusplus
}
#endif
#endif
