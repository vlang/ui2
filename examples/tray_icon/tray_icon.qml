Screen {
    id: root
    background: #F1F5F9

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Tray icon" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: backend_note text: app.backend_note x: 18 y: 44 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Rectangle { x: 18 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Docked" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: docked_state text: app.docked ? "yes" : "no" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }
        Rectangle { x: 178 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Status" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: status_state text: app.status x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }
        Rectangle { x: 338 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Notifications" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: notifications_state text: app.notifications ? "on" : "off" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }

        Rectangle { x: 18 y: 142 width: card.width - 36 height: 44 background: #DCFCE7 corner_radius: 8
            Label { id: last_action text: app.last_action x: 14 y: 0 width: card.width - 64 height: 44 color: #166534 font_size: 13 }
        }

        Button { id: tray_show text: "Dock tray icon" on_tap: "tray_show" native: true enabled: app.supported && !app.docked x: 18 y: 198 width: 140 height: 32 }
        Button { id: tray_hide text: "Hide tray icon" on_tap: "tray_hide" native: true enabled: app.supported && app.docked x: 168 y: 198 width: 140 height: 32 }

        Label { id: fallback_title hidden: app.supported text: "The same rows, without a status area" x: 18 y: 244 width: card.width - 36 height: 18 color: #64748B font_size: 12 }
        Button { id: fallback_status hidden: app.supported text: "Show status" on_tap: "tray_status" native: true x: 18 y: 266 width: 130 height: 30 }
        Button { id: fallback_notifications hidden: app.supported text: "Notifications" on_tap: "tray_notifications" native: true x: 156 y: 266 width: 130 height: 30 }
        Button { id: fallback_available hidden: app.supported text: "Available" on_tap: "status_available" native: true x: 294 y: 266 width: 100 height: 30 }
        Button { id: fallback_busy hidden: app.supported text: "Busy" on_tap: "status_busy" native: true x: 402 y: 266 width: 90 height: 30 }
        Button { id: fallback_away hidden: app.supported text: "Away" on_tap: "status_away" native: true x: 500 y: 266 width: 90 height: 30 }

        TextArea {
            id: tray_log
            text: app.log
            editable: false
            x: 18
            y: app.supported ? 244 : 308
            width: card.width - 36
            height: card.height - (app.supported ? 262 : 326)
            background: #F8FAFC
            color: #334155
            font_size: 13
            corner_radius: 7
        }
    }
}
