import AppKit

/// Draws the cute axe menu bar icon as a template image (adapts to light/dark menu bars).
enum AxeIcon {
    /// - Parameter blocking: adds a small dot to show restricted apps are currently being blocked.
    static func image( blocking: Bool = false ) -> NSImage {
        let size = NSSize( width: 20, height: 20 )
        let image = NSImage( size: size, flipped: false ) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // Handle: a slightly curved diagonal stick.
            let handle = NSBezierPath()
            handle.lineWidth = 2.2
            handle.lineCapStyle = .round
            handle.move( to: NSPoint( x: 4.5, y: 2.5 ) )
            handle.curve( to: NSPoint( x: 13.5, y: 14.5 ), controlPoint1: NSPoint( x: 7.0, y: 5.0 ), controlPoint2: NSPoint( x: 11.0, y: 10.5 ) )
            handle.stroke()

            // Blade: a chunky, rounded wedge at the top of the handle.
            let blade = NSBezierPath()
            blade.move( to: NSPoint( x: 10.5, y: 17.5 ) )
            blade.curve( to: NSPoint( x: 17.5, y: 15.5 ), controlPoint1: NSPoint( x: 13.5, y: 19.0 ), controlPoint2: NSPoint( x: 16.5, y: 18.0 ) )
            blade.curve( to: NSPoint( x: 15.0, y: 8.5 ), controlPoint1: NSPoint( x: 19.0, y: 13.0 ), controlPoint2: NSPoint( x: 17.5, y: 10.5 ) )
            blade.curve( to: NSPoint( x: 10.5, y: 17.5 ), controlPoint1: NSPoint( x: 13.5, y: 12.0 ), controlPoint2: NSPoint( x: 11.5, y: 15.0 ) )
            blade.close()
            blade.fill()

            if blocking {
                NSBezierPath( ovalIn: NSRect( x: 1.0, y: 13.0, width: 5.0, height: 5.0 ) ).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
