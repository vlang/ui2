// @ts-check
/*
 * ui2 web renderer — a small, framework-free DOM renderer for the Element tree
 * produced by ui2's BuildFn. Authored as type-checked JavaScript so a browser
 * can load it directly with no toolchain; `tsconfig.json` enables checkJs.
 *
 * Wire contract (see docs/web-backend.md):
 *   server -> client: { type: 'snapshot', seq, title, width, height, dpr, root }
 *                   | { type: 'patch', seq, ops: [...] }
 *                   | { type: 'error', message }
 *   client -> server: { type, id, value, x, y, dx, dy, key, code, ...modifiers }
 */
(function () {
  'use strict';

  /** @typedef {{[key: string]: any}} Obj */

  const root = /** @type {HTMLElement} */ (document.getElementById('ui2-root'));
  const configEl = document.getElementById('ui2-config');
  /** @type {Obj} */
  let config = {};
  try {
    config = JSON.parse(configEl ? (configEl.textContent || '{}') : '{}');
  } catch (e) {
    showError('Invalid ui2 page configuration');
  }

  const token = typeof config.token === 'string' ? config.token : '';
  const snapshotUrl = typeof config.snapshotUrl === 'string' ? config.snapshotUrl : '/snapshot';
  const wsPath = typeof config.wsPath === 'string' ? config.wsPath : '/events';

  /** @type {Obj|null} */ let tree = null;
  /** @type {number} */ let seq = 0;
  /** @type {WebSocket|null} */ let socket = null;
  /** @type {Map<string, HTMLElement>} */ const byPath = new Map();
  /** @type {number|null} */ var reconnectTimer = null;

  // ── small helpers ────────────────────────────────────────────────────────

  /**
   * ui2 colors are 0xRRGGBB (an optional high byte is alpha).
   * @param {number} color
   * @param {number} [alphaOverride]
   */
  function cssColor(color, alphaOverride) {
    const n = Number(color) >>> 0;
    const r = (n >> 16) & 255;
    const g = (n >> 8) & 255;
    const b = n & 255;
    const embedded = (n >>> 24) & 255;
    let a = alphaOverride === undefined ? (embedded ? embedded / 255 : 1) : alphaOverride;
    if (a < 0) a = 0;
    if (a > 1) a = 1;
    return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';
  }

  /** @param {number} n */
  function px(n) {
    return Number(n || 0) + 'px';
  }

  /**
   * CSS linear-gradient measures 0deg upward and 90deg right; ui2 measures 0
   * right and 90 down, so adding 90 maps one onto the other.
   * @param {Obj} gradient
   */
  function cssGradient(gradient) {
    if (!gradient || !Array.isArray(gradient.stops) || gradient.stops.length < 2) return '';
    const angle = ((90 + Number(gradient.angle || 0)) % 360 + 360) % 360;
    const stops = gradient.stops.map(function (/** @type {Obj} */ s) {
      return cssColor(s.color, s.opacity) + ' ' + (Number(s.position || 0) * 100).toFixed(2) + '%';
    });
    return 'linear-gradient(' + angle + 'deg,' + stops.join(',') + ')';
  }

  /**
   * @param {Obj} box
   * @param {Obj} frame
   */
  function boxStyle(box, frame) {
    box = box || {};
    frame = frame || {};
    const styles = [
      'left:' + px(frame.x),
      'top:' + px(frame.y),
      'width:' + px(frame.width),
      'height:' + px(frame.height)
    ];
    const gradient = cssGradient(box.gradient);
    if (box.transparent) {
      styles.push('background:transparent');
    } else if (gradient) {
      styles.push('background:' + gradient);
    } else {
      styles.push('background:' + cssColor(box.bg === undefined ? 0xffffff : box.bg, box.opacity));
    }
    const radius = Number(box.radius || 0);
    if (radius > 0) styles.push('border-radius:' + px(radius));
    const sides = [
      ['border-left', box.border_left],
      ['border-top', box.border_top],
      ['border-right', box.border_right],
      ['border-bottom', box.border_bottom]
    ];
    for (const [name, width] of sides) {
      const w = Number(width || 0);
      styles.push(name + ':' + px(w) + (w > 0 ? ' solid ' + cssColor(box.border_color || 0) : ' none'));
    }
    const shadow = box.shadow;
    if (shadow && Number(shadow.blur || 0) + Number(shadow.spread || 0) > 0) {
      styles.push(
        'box-shadow:' + px(shadow.x || 0) + ' ' + px(shadow.y || 0) + ' ' +
        px(shadow.blur || 0) + ' ' + px(shadow.spread || 0) + ' ' +
        cssColor(shadow.color || 0, shadow.opacity)
      );
    }
    return styles.join(';');
  }

  /** @param {Obj} style */
  function textStyle(style) {
    style = style || {};
    const out = [
      'color:' + cssColor(style.color === undefined ? 0x111111 : style.color),
      'font-size:' + px(style.size || 15),
      'font-family:' + (style.font_family ? String(style.font_family) : 'system-ui, -apple-system, sans-serif')
    ];
    if (style.bold) out.push('font-weight:700');
    if (style.italic) out.push('font-style:italic');
    if (style.underline) out.push('text-decoration:underline');
    if (style.strikethrough) out.push('text-decoration:line-through');
    const align = String(style.align || 'left');
    out.push('text-align:' + (align === 'center' ? 'center' : align === 'right' ? 'right' : 'left'));
    const valign = String(style.valign || 'top');
    out.push('align-items:' + (valign === 'middle' ? 'center' : valign === 'bottom' ? 'flex-end' : 'flex-start'));
    return out.join(';');
  }

  /**
   * @param {Obj} dto
   * @returns {HTMLElement}
   */
  function createNode(dto) {
    const kind = String(dto.kind || 'view');
    let node;
    switch (kind) {
      case 'button':
      case 'toggle_button':
        node = document.createElement('button');
        break;
      case 'text_field':
        node = document.createElement('input');
        /** @type {HTMLInputElement} */ (node).type = 'text';
        break;
      case 'text_area':
        node = document.createElement('textarea');
        break;
      case 'checkbox':
        node = document.createElement('input');
        /** @type {HTMLInputElement} */ (node).type = 'checkbox';
        break;
      case 'dropdown':
        node = document.createElement('select');
        break;
      case 'slider':
        node = document.createElement('input');
        /** @type {HTMLInputElement} */ (node).type = 'range';
        break;
      case 'switch_control':
        node = document.createElement('button');
        node.setAttribute('role', 'switch');
        break;
      case 'image':
        node = document.createElement('img');
        break;
      case 'opengl':
        node = document.createElement('canvas');
        break;
      case 'scroll':
        node = document.createElement('div');
        node.style.overflowX = String(dto.scroll_mode || 'vertical_only') === 'horizontal_only' ? 'auto' : 'hidden';
        node.style.overflowY = String(dto.scroll_mode || 'vertical_only') === 'horizontal_only' ? 'hidden' : 'auto';
        break;
      default:
        node = document.createElement('div');
    }

    node.style.position = 'absolute';
    node.style.boxSizing = 'border-box';
    node.dataset.ui2Id = dto.id || '';
    node.dataset.ui2Kind = kind;
    if (dto.hidden) node.style.display = 'none';
    if (!dto.enabled) {
      node.setAttribute('disabled', '');
      /** @type {any} */ (node).disabled = true;
    }
    if (dto.tooltip) node.title = String(dto.tooltip);
    if (dto.accessibility_role) node.setAttribute('role', String(dto.accessibility_role));
    if (dto.accessibility_label) node.setAttribute('aria-label', String(dto.accessibility_label));
    if (dto.accessibility_value) node.setAttribute('aria-valuenow', String(dto.accessibility_value));
    // aria-checked / aria-pressed (and their visual cue) are applied by
    // updateNode so both initial creation and later patches use one path.
    if (dto.secure && kind === 'text_field') /** @type {HTMLInputElement} */ (node).type = 'password';

    updateNode(node, dto, null);

    if (Array.isArray(dto.children)) {
      for (const child of dto.children) node.appendChild(createNode(child));
    }
    if (kind === 'dropdown' && Array.isArray(dto.menu)) {
      for (const entry of dto.menu) {
        const option = document.createElement('option');
        option.value = String(entry.id || entry.title || '');
        option.textContent = String(entry.title || '');
        if (String(entry.title || '') === String(dto.text || '')) option.selected = true;
        node.appendChild(option);
      }
    }
    if (kind === 'opengl') {
      node.textContent = 'OpenGL surface (not available on the web backend)';
      node.style.display = 'grid';
      node.style.placeItems = 'center';
      node.style.color = '#6b7280';
      node.style.fontSize = '12px';
    }
    if (kind === 'image' && typeof dto.image_path === 'string' && dto.image_path) {
      /** @type {HTMLImageElement} */ (node).src = dto.image_path.startsWith('/') ? dto.image_path : '/' + dto.image_path;
      /** @type {HTMLImageElement} */ (node).alt = String(dto.accessibility_label || dto.id || 'image');
    }

    wireEvents(node, dto);
    return node;
  }

  /**
   * Update only the scalar fields of an existing DOM node. Children are left
   * alone so typing and scroll state survive a patch.
   * @param {HTMLElement} node
   * @param {Obj} dto
   * @param {Obj|null} _parent
   */
  function updateNode(node, dto, _parent) {
    const kind = String(dto.kind || node.dataset.ui2Kind || 'view');
    node.style.cssText = 'position:absolute;box-sizing:border-box;' + boxStyle(dto.box, dto.frame);
    node.style.display = dto.hidden ? 'none' : '';
    if (!dto.enabled) node.setAttribute('disabled', '');
    else node.removeAttribute('disabled');
    /** @type {any} */ (node).disabled = !dto.enabled;

    // Text-bearing container kinds. `text_area` is handled with the value
    // inputs below; writing textContent here would only clobber its value.
    const textKind = kind === 'button' || kind === 'toggle_button' ||
      kind === 'switch_control' || kind === 'label' || kind === 'view';
    if (textKind) {
      const text = String(dto.text || '');
      if (node.children.length > 0) {
        // Never assign textContent on a container: it detaches every child
        // element. createNode writes the element's own text as the leading
        // text node before appending children, so update only that node.
        const first = node.firstChild;
        if (first && first.nodeType === 3 /* TEXT_NODE */) {
          if (first.nodeValue !== text) first.nodeValue = text;
        }
      } else if (node.textContent !== text) {
        node.textContent = text;
      }
      node.style.cssText += ';' + textStyle(dto.text_style);
      if (kind === 'label') node.style.display = 'flex';
    }
    if (kind === 'text_field' || kind === 'text_area') {
      const value = String(dto.text === undefined ? '' : dto.text);
      if (/** @type {any} */ (node).value !== value) /** @type {any} */ (node).value = value;
      if (dto.placeholder) /** @type {any} */ (node).placeholder = String(dto.placeholder);
      /** @type {any} */ (node).readOnly = !!dto.readonly;
      node.style.cssText += ';' + textStyle(dto.text_style);
    }
    if (kind === 'checkbox') /** @type {HTMLInputElement} */ (node).checked = !!dto.checked;
    if (kind === 'slider') {
      const input = /** @type {HTMLInputElement} */ (node);
      input.min = String(dto.min_value || 0);
      input.max = String(dto.max_value || 100);
      input.step = String(dto.step || 'any');
      const value = String(dto.value === undefined ? 0 : dto.value);
      if (input.value !== value) input.value = value;
    }
    // Toggle state: keep ARIA in sync and add a real visual cue. `outline`
    // is used (not background/box-shadow) so the element's BoxStyle and its
    // absolute-positioned children are left untouched.
    if (kind === 'switch_control') {
      const checked = !!dto.checked;
      node.setAttribute('aria-checked', checked ? 'true' : 'false');
      node.style.cssText += checked
        ? ';outline:3px solid #2563eb;outline-offset:-3px;'
        : ';outline:2px solid #9ca3af;outline-offset:-2px;';
    }
    if (kind === 'toggle_button') {
      const pressed = !!dto.pressed;
      node.setAttribute('aria-pressed', pressed ? 'true' : 'false');
      node.style.cssText += pressed
        ? ';outline:2px solid #2563eb;outline-offset:-2px;'
        : ';outline:none;';
    }
  }

  /** @param {HTMLElement} node @param {Obj} dto */
  function wireEvents(node, dto) {
    const kind = String(dto.kind || 'view');
    const action = String(dto.action_id || dto.id || '');
    if (!action && !dto.clickable && !dto.hoverable && !dto.draggable) return;

    if (kind === 'button' || kind === 'toggle_button' || kind === 'switch_control' || dto.button_behavior) {
      node.addEventListener('click', function () { emitElement('tap', dto, { value: action }); });
    }
    if (kind === 'text_field' || kind === 'text_area') {
      node.addEventListener('input', function () {
        emitElement('change', dto, { value: /** @type {any} */ (node).value });
      });
      node.addEventListener('keydown', function (ev) {
        if (ev.key === 'Enter') emitElement('key', dto, { key: 'enter', code: 13 });
      });
    }
    if (kind === 'checkbox') {
      node.addEventListener('change', function () {
        emitElement('change', dto, { value: /** @type {HTMLInputElement} */ (node).checked ? 'true' : 'false' });
      });
    }
    if (kind === 'dropdown') {
      node.addEventListener('change', function () {
        emitElement('change', dto, { value: /** @type {HTMLSelectElement} */ (node).value });
      });
    }
    if (kind === 'slider') {
      node.addEventListener('input', function () {
        emitElement('change', dto, { value: /** @type {HTMLInputElement} */ (node).value });
      });
    }
    if (kind === 'scroll') {
      let lastTop = 0;
      let lastLeft = 0;
      node.addEventListener('scroll', function () {
        emitElement('scroll', dto, {
          dx: node.scrollLeft - lastLeft,
          dy: node.scrollTop - lastTop,
          value: String(node.scrollTop)
        });
        lastLeft = node.scrollLeft;
        lastTop = node.scrollTop;
      });
    }

    if (dto.clickable || dto.hoverable || dto.draggable) {
      node.addEventListener('pointerdown', function (ev) { pointer(ev, 'down', dto); });
      node.addEventListener('pointerup', function (ev) { pointer(ev, 'up', dto); });
      node.addEventListener('pointermove', function (ev) {
        pointer(ev, (ev.buttons & 1) ? 'drag' : 'move', dto);
      });
      node.addEventListener('pointerenter', function (ev) { pointer(ev, 'enter', dto); });
      node.addEventListener('pointerleave', function (ev) { pointer(ev, 'leave', dto); });
    }
  }

  /** @param {PointerEvent} ev @param {string} phase @param {Obj} dto */
  function pointer(ev, phase, dto) {
    // The server forwards x/y straight into the desktop-style pointer string,
    // so convert viewport CSS pixels to the logical units the frame uses.
    const dpr = Number(config.dpr) || 1;
    emitElement('pointer', dto, {
      value: phase,
      x: Math.round(ev.clientX * dpr * 100) / 100,
      y: Math.round(ev.clientY * dpr * 100) / 100
    });
  }

  /**
   * @param {string} type
   * @param {string} id
   * @param {Obj} [extra]
   * @param {string} [action]
   */
  function emit(type, id, extra, action) {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;
    /** @type {Obj} */
    const event = { type: type, id: id || '', token: token };
    if (action !== undefined) event.action = action;
    if (extra) Object.assign(event, extra);
    socket.send(JSON.stringify(event));
  }

  /**
   * Emit an event belonging to a concrete element. `id` is kept for server-side
   * state lookup; `action` mirrors element_action_id() so web_event_string()
   * produces the same EventFn string as the desktop backends.
   * @param {string} type
   * @param {Obj} dto
   * @param {Obj} [extra]
   */
  function emitElement(type, dto, extra) {
    emit(type, String(dto.id || ''), extra, String(dto.action_id || dto.id || ''));
  }

  // ── rendering and patching ───────────────────────────────────────────────

  /** @param {Obj} snapshot */
  function renderSnapshot(snapshot) {
    clearError();
    tree = snapshot.root;
    seq = Number(snapshot.seq || 0);
    config.dpr = snapshot.dpr || config.dpr;
    config.width = snapshot.width || config.width;
    config.height = snapshot.height || config.height;
    document.title = String(snapshot.title || document.title);
    root.style.width = px(config.width);
    root.style.height = px(config.height);
    root.replaceChildren(createNode(tree));
    indexDom();
  }

  function indexDom() {
    byPath.clear();
    if (!tree || !root.firstElementChild) return;
    // Walk the DOM with the same child ordering as the tree so patch paths can
    // be resolved to a live node without a full re-render.
    /** @param {HTMLElement} dom @param {Obj} dto @param {number[]} path */
    function index(dom, dto, path) {
      byPath.set(path.join('/'), dom);
      const children = Array.isArray(dto.children) ? dto.children : [];
      for (let i = 0; i < children.length && i < dom.children.length; i++) {
        index(/** @type {HTMLElement} */ (dom.children[i]), children[i], path.concat(i));
      }
    }
    index(/** @type {HTMLElement} */ (root.firstElementChild), tree, []);
  }

  /** @param {Obj} message */
  function applyPatch(message) {
    if (!tree) {
      fetchSnapshot();
      return;
    }
    seq = Number(message.seq || seq);
    const ops = Array.isArray(message.ops) ? message.ops : [];
    let structural = false;
    for (const op of ops) {
      if (op.kind === 'update') {
        const dto = nodeAtPath(tree, op.path);
        if (dto && op.element) {
          // An update carries a full Element DTO, but children belong to the
          // existing tree (the diff emits separate child ops). Keep them so a
          // scalar patch never wipes the subtree or its live DOM nodes.
          const merged = Object.assign({}, op.element, { children: dto.children || [] });
          // Keep the reference in the tree fresh for later patches. The
          // return matters for the root path, where replaceAtPath cannot
          // mutate the tree in place.
          tree = replaceAtPath(tree, op.path, merged);
          const dom = byPath.get(pathKey(op.path));
          if (dom) updateNode(dom, merged, null);
          else structural = true;
        } else {
          structural = true;
        }
      } else if (op.kind === 'replace_children') {
        structural = true;
      }
    }
    if (structural) {
      // A structural change re-renders the whole tree. Correct first; the
      // common scalar-only path above stays in place and keeps focus.
      const snapshot = {
        seq: seq,
        dpr: config.dpr,
        width: config.width,
        height: config.height,
        title: document.title,
        root: tree
      };
      for (const op of ops) {
        if (op.kind === 'replace_children') {
          // nodeAtPath returns the root dto itself for the empty path, so
          // replacing the root's children needs no special case here.
          setChildrenAtPath(tree, op.path, op.children || []);
        }
      }
      snapshot.root = tree;
      renderSnapshot(snapshot);
    }
  }

  /** @param {any} path */
  function pathKey(path) {
    return Array.isArray(path) ? path.join('/') : '';
  }

  /** @param {Obj} dto @param {number[]} path */
  function nodeAtPath(dto, path) {
    let current = dto;
    for (const index of path || []) {
      const children = Array.isArray(current.children) ? current.children : [];
      if (index < 0 || index >= children.length) return null;
      current = children[index];
    }
    return current;
  }

  /**
   * @param {Obj} dto
   * @param {number[]} path
   * @param {Obj} value
   */
  function replaceAtPath(dto, path, value) {
    if (!path || path.length === 0) return value;
    const children = Array.isArray(dto.children) ? dto.children : [];
    const index = path[0];
    if (index >= 0 && index < children.length) {
      children[index] = replaceAtPath(children[index], path.slice(1), value);
    }
    return dto;
  }

  /**
   * @param {Obj} dto
   * @param {number[]} path
   * @param {Obj[]} children
   */
  function setChildrenAtPath(dto, path, children) {
    const target = nodeAtPath(dto, path);
    if (target) target.children = children;
    return dto;
  }

  // ── transport ────────────────────────────────────────────────────────────

  function fetchSnapshot() {
    fetch(snapshotUrl, { credentials: 'same-origin' })
      .then(function (r) {
        if (!r.ok) throw new Error('snapshot request failed: ' + r.status);
        return r.json();
      })
      .then(function (snapshot) { renderSnapshot(/** @type {Obj} */ (snapshot)); })
      .catch(function (err) { showError('Snapshot failed: ' + err.message); });
  }

  function connect() {
    if (reconnectTimer !== null) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }
    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const query = token ? '?token=' + encodeURIComponent(token) : '';
    socket = new WebSocket(proto + '//' + location.host + wsPath + query);
    socket.onopen = function () { clearError(); };
    socket.onmessage = function (event) {
      let message;
      try {
        message = JSON.parse(event.data);
      } catch (e) {
        showError('Malformed websocket message');
        return;
      }
      if (message.type === 'snapshot') renderSnapshot(message);
      else if (message.type === 'patch') applyPatch(message);
      else if (message.type === 'error') showError(String(message.message || 'server error'));
    };
    socket.onclose = function () {
      socket = null;
      reconnectTimer = setTimeout(connect, 500);
    };
    socket.onerror = function () {
      showError('Websocket disconnected; retrying…');
    };
  }

  // There is at most one overlay element: showError reuses it instead of
  // appending a new one on every retry, and clearError removes it once the
  // connection (or a fresh snapshot) is healthy.
  function clearError() {
    const overlay = document.getElementById('ui2-error');
    if (overlay) overlay.remove();
  }

  /** @param {string} text */
  function showError(text) {
    let overlay = document.getElementById('ui2-error');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'ui2-error';
      overlay.style.cssText =
        'position:fixed;left:0;right:0;bottom:0;z-index:9999;background:#7f1d1d;color:#fff;' +
        'font:12px/1.4 ui-monospace,monospace;padding:8px 12px;white-space:pre-wrap';
      document.body.appendChild(overlay);
    }
    overlay.textContent = text;
  }

  window.addEventListener('keydown', function (ev) {
    /** @type {Obj} */
    const extra = { key: ev.key.length === 1 ? ev.key.toLowerCase() : ev.key, code: ev.keyCode };
    if (ev.metaKey) extra.cmd = true;
    if (ev.ctrlKey) extra.ctrl = true;
    if (ev.altKey) extra.alt = true;
    if (ev.shiftKey) extra.shift = true;
    emit('key', '', extra);
  });

  let resizeTimer = null;
  window.addEventListener('resize', function () {
    if (resizeTimer !== null) clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      config.dpr = window.devicePixelRatio || 1;
      emit('resize', '', { x: window.innerWidth, y: window.innerHeight, value: String(config.dpr) });
    }, 50);
  });

  fetchSnapshot();
  connect();
})();
