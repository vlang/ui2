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

        Label { text: "Timer" x: 18 y: 14 width: 160 height: 28 color: #111827 font_size: 18 bold: true }
        Label { text: app.elapsed_label x: card.width - 170 y: 12 width: 152 height: 34 align: right color: #2563EB font_size: 21 bold: true font_family: "Courier New" }

        Label { text: "Elapsed time" x: 20 y: 64 width: card.width - 40 height: 20 color: #475569 font_size: 12 }
        ProgressBar { id: elapsed_progress x: 20 y: 92 width: card.width - 40 height: 28 value: app.elapsed max: app.duration background: #E2E8F0 color: app.running ? #22C55E : #60A5FA corner_radius: 14 accessibility_label: "Elapsed time" }

        Label { text: "Duration" x: 20 y: 148 width: 100 height: 20 color: #475569 font_size: 12 bold: true }
        Label { text: app.duration_label x: card.width - 160 y: 148 width: 140 height: 20 align: right color: #334155 font_size: 12 }
        Rectangle { id: duration_track on_tap: "duration_track" clickable: true draggable: true cursor: "pointing_hand" x: 36 y: 184 width: card.width - 72 height: 24 background: #CBD5E1 corner_radius: 12
            Rectangle { x: 0 y: 0 width: app.duration_ratio * duration_track.width height: 24 background: #BFDBFE corner_radius: 12 }
            Rectangle { x: app.duration_ratio * (duration_track.width - 22) y: 1 width: 22 height: 22 background: #2563EB corner_radius: 11 }
        }
        Label { text: "1 s" x: 36 y: 214 width: 50 height: 18 color: #64748B font_size: 10 }
        Label { text: "30 s" x: card.width - 86 y: 214 width: 50 height: 18 align: right color: #64748B font_size: 10 }

        Button { id: start text: app.start_label on_tap: "start" native: true x: card.width / 2 - 118 y: 250 width: 110 height: 34 }
        Button { id: pause text: app.running ? "Pause" : "Resume" on_tap: "pause" native: true enabled: app.elapsed > 0 && app.elapsed < app.duration x: card.width / 2 + 8 y: 250 width: 110 height: 34 }
        Label { id: timer_status text: app.status x: 20 y: card.height - 38 width: card.width - 40 height: 18 align: center color: #166534 font_size: 11 }
    }
}
