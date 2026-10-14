import AppKit

/// Draws the cute axe menu bar icon (adapts to light/dark menu bars).
enum AxeIcon {
    /// - Parameter dotColor: optional color for the status dot (e.g. systemRed while blocked, systemGreen when allowed).
    static func image( dotColor: NSColor? = nil ) -> NSImage {
        let size = NSSize( width: 20, height: 20 )
        let image = NSImage( size: size, flipped: false ) { _ in
            let axeColor: NSColor
            if dotColor != nil {
                let app = NSAppearance.currentDrawing()
                let isDark = app.bestMatch( from: [ .darkAqua, .aqua ] ) == .darkAqua
                axeColor = isDark ? .white : .black
            }
            else {
                axeColor = .black
            }
            axeColor.setFill()
            axeColor.setStroke()

            // 1. Handle (haft): ergonomic curved shaft extending through the head.
            let handle = NSBezierPath()
            handle.lineWidth = 2.0
            handle.lineCapStyle = .round
            handle.move( to: NSPoint( x: 3.5, y: 2.5 ) )
            handle.curve( to: NSPoint( x: 13.5, y: 17.5 ),
                          controlPoint1: NSPoint( x: 6.5, y: 6.5 ),
                          controlPoint2: NSPoint( x: 10.5, y: 12.0 ) )
            handle.stroke()

            // 2. Axe Head: flat poll (hammer butt) at back, eye around handle, and curved bearded blade.
            let head = NSBezierPath()
            // Top edge of poll
            head.move( to: NSPoint( x: 9.5, y: 15.0 ) )
            // Back face of poll
            head.line( to: NSPoint( x: 7.5, y: 13.0 ) )
            // Bottom of poll into collar under the eye
            head.line( to: NSPoint( x: 10.5, y: 11.5 ) )
            // Throat curving forward into the beard
            head.curve( to: NSPoint( x: 13.5, y: 9.0 ),
                        controlPoint1: NSPoint( x: 11.5, y: 10.0 ),
                        controlPoint2: NSPoint( x: 12.2, y: 9.0 ) )
            // Cutting edge arc: from beard (13.5, 9.0) up to toe (18.5, 14.5)
            head.curve( to: NSPoint( x: 18.5, y: 14.5 ),
                        controlPoint1: NSPoint( x: 17.0, y: 10.0 ),
                        controlPoint2: NSPoint( x: 18.5, y: 12.5 ) )
            // Top edge of blade from toe back to eye
            head.curve( to: NSPoint( x: 12.5, y: 16.5 ),
                        controlPoint1: NSPoint( x: 16.5, y: 16.0 ),
                        controlPoint2: NSPoint( x: 14.5, y: 16.5 ) )
            // Eye across to poll
            head.line( to: NSPoint( x: 9.5, y: 15.0 ) )
            head.close()
            head.fill()

            if let dotColor = dotColor {
                dotColor.setFill()
                NSBezierPath( ovalIn: NSRect( x: 1.0, y: 13.0, width: 4.5, height: 4.5 ) ).fill()
            }
            return true
        }
        image.isTemplate = ( dotColor == nil )
        return image
    }

    /// Convenience overload matching earlier API.
    static func image( blocking: Bool ) -> NSImage {
        image( dotColor: blocking ? .systemRed : nil )
    }
}
