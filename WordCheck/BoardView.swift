import UIKit

final class BoardSquareElement: UIAccessibilityElement {
    var action: (() -> Void)?
    override func accessibilityActivate() -> Bool { action?(); return true }
}
final class BoardCanvas: UIView {
    static let cell: CGFloat = 44
    static let margin: CGFloat = 4
    static let side: CGFloat = 668
    var tiles = [Tile?](repeating: nil, count: 225) { didSet { if tiles != oldValue { refresh() } } }
    var draft: [Placement] = [] { didSet { if draft != oldValue { refresh() } } }
    var vertical=false { didSet { if vertical != oldValue { setNeedsDisplay() } } }
    var selected: Int? { didSet { if selected != oldValue { setNeedsDisplay() } } }
    var onToggleDirection: (() -> Void)?
    private var squareElements: [BoardSquareElement] = []
    var onSelect: ((Int) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        isAccessibilityElement = false
        accessibilityIdentifier = "boardCanvas"
        squareElements = (0..<225).map { i in
            let element = BoardSquareElement(accessibilityContainer: self)
            element.accessibilityIdentifier = "square-\(i)"
            element.accessibilityTraits = [.button]
            element.accessibilityFrameInContainerSpace = rect(i)
            element.action = { [weak self] in self?.choose(i) }
            return element
        }
        accessibilityElements = squareElements
        refresh()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: BoardCanvas, _: UITraitCollection) in self.setNeedsDisplay() }
    }
    required init?(coder: NSCoder) { fatalError() }
    func choose(_ index: Int) { onSelect?(index) }
    private func refresh() {
        setNeedsDisplay()
        for i in 0..<225 {
            let tile = draft.first(where: { $0.index == i })?.tile ?? tiles[i]
            let premium = BoardRules.premium(i)
            squareElements[i].accessibilityLabel = "\(BoardRules.coordinate(i)), \(tile.map { $0.letter + ($0.blank ? ", blank" : ", \($0.value) points") } ?? (i == 112 ? "center, double word" : premium.rawValue.isEmpty ? "empty" : premium.rawValue))"
        }
    }

    func rect(_ index: Int) -> CGRect { CGRect(x: Self.margin + CGFloat(index % 15)*Self.cell, y: Self.margin + CGFloat(index / 15)*Self.cell, width: Self.cell, height: Self.cell) }
    override func draw(_ rect: CGRect) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        func text(_ string: String, _ rect: CGRect, _ size: CGFloat, _ color: UIColor, _ weight: UIFont.Weight = .medium) {
            (string as NSString).draw(in: rect, withAttributes: [.font:UIFont.systemFont(ofSize:size, weight:weight),.foregroundColor:color,.paragraphStyle:paragraph])
        }
        for i in 0..<225 where self.rect(i).intersects(rect) {
            let box = self.rect(i).insetBy(dx:1,dy:1)
            let p = BoardRules.premium(i)
            let color: UIColor
            let dark = traitCollection.userInterfaceStyle == .dark
            switch p {
            case .none: color = .tertiarySystemFill
            case .doubleLetter: color = .systemTeal.withAlphaComponent(dark ? 0.40 : 0.18)
            case .tripleLetter: color = .systemBlue.withAlphaComponent(dark ? 0.45 : 0.22)
            case .doubleWord: color = .systemOrange.withAlphaComponent(dark ? 0.40 : 0.18)
            case .tripleWord: color = .systemPurple.withAlphaComponent(dark ? 0.45 : 0.20)
            }
            let active = selected == i
            let inLine = selected.map { vertical ? $0 % 15 == i % 15 : $0 / 15 == i / 15 } ?? false
            let selectionColor = UIColor.systemBlue
            let newTile = draft.first(where: { $0.index == i })?.tile
            if let tile = newTile ?? tiles[i] {
                (active ? selectionColor : inLine ? selectionColor.withAlphaComponent(dark ? 0.35 : 0.18) : tile.blank ? UIColor.systemYellow.withAlphaComponent(dark ? 0.32 : 0.24) : newTile != nil ? UIColor.systemGreen.withAlphaComponent(0.23) : UIColor.secondarySystemBackground).setFill()
                UIBezierPath(roundedRect:box,cornerRadius:6).fill()
                UIColor.separator.setStroke(); let outline = UIBezierPath(roundedRect:box,cornerRadius:6); outline.lineWidth=0.7; outline.stroke()
                text(tile.letter.uppercased(),CGRect(x:box.minX,y:box.minY+2,width:box.width,height:32),26,active ? .white : .label,.semibold)
                if tile.blank {
                    let badge=CGRect(x:box.maxX-17,y:box.maxY-17,width:16,height:16)
                    UIColor.systemYellow.setFill(); UIBezierPath(ovalIn:badge).fill()
                    text("0",badge.insetBy(dx:1,dy:0),12,.black,.bold)
                } else {
                    text("\(tile.value)",CGRect(x:box.maxX-13,y:box.maxY-14,width:11,height:12),9,active ? .white : .secondaryLabel)
                }
            } else {
                (active ? selectionColor : inLine ? selectionColor.withAlphaComponent(dark ? 0.35 : 0.18) : color).setFill(); UIBezierPath(roundedRect:box,cornerRadius:4).fill()
                text(i == 112 ? "★" : p.rawValue,CGRect(x:box.minX,y:box.minY+13,width:box.width,height:20),13,active ? .white : .label,.bold)
            }

        }
    }
}
final class ZoomBoard: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let canvas = BoardCanvas(frame: CGRect(x:0,y:0,width:BoardCanvas.side,height:BoardCanvas.side))
    private var doubleWasSelected=false
    private var previousSize = CGSize.zero
    var onScale: ((CGFloat) -> Void)?
    override init(frame: CGRect) {
        super.init(frame:frame)
        delegate=self
        addSubview(canvas)
        contentSize=canvas.bounds.size
        showsHorizontalScrollIndicator=false; showsVerticalScrollIndicator=false
        bouncesZoom=true; decelerationRate = .fast
        accessibilityIdentifier="zoomBoard"
        let tap=UITapGestureRecognizer(target:self,action:#selector(tapped(_:)))
        let double=UITapGestureRecognizer(target:self,action:#selector(doubled(_:))); double.numberOfTapsRequired=2
        // Select on the first tap without waiting for the double-tap timeout.
        tap.delegate=self; double.delegate=self
        addGestureRecognizer(tap); addGestureRecognizer(double)
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name:"Fit board", actionHandler:{ [weak self] _ in self?.fit(); return true }),
            UIAccessibilityCustomAction(name:"Zoom in", actionHandler:{ [weak self] _ in self?.magnify(); return true })
        ]
        backgroundColor = .systemBackground
    }
    required init?(coder:NSCoder){fatalError()}
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if previousSize != bounds.size {
            let wasFit = previousSize == .zero || abs(zoomScale-minimumZoomScale)<0.02
            minimumZoomScale=min(bounds.width,bounds.height)/BoardCanvas.side
            maximumZoomScale=max(2,minimumZoomScale*4)
            if wasFit && (previousSize == .zero || previousSize.width != bounds.width || bounds.height > previousSize.height) { setZoomScale(minimumZoomScale,animated:false) }
            if bounds.height < previousSize.height, let selected=canvas.selected {
                centerBoard()
                let target=canvas.rect(selected)
                let x=max(-contentInset.left,min(contentSize.width-bounds.width+contentInset.right,target.midX*zoomScale-bounds.width/2))
                let y=max(-contentInset.top,min(contentSize.height-bounds.height+contentInset.bottom,target.midY*zoomScale-bounds.height/2))
                contentOffset=CGPoint(x:x,y:y)
            }
            previousSize=bounds.size
        }
        centerBoard()
    }
    private func centerBoard() {
        contentInset = UIEdgeInsets(top:max(0,(bounds.height-canvas.frame.height)/2),left:max(0,(bounds.width-canvas.frame.width)/2),bottom:0,right:0)
        accessibilityValue=String(format:"%.0f percent",zoomScale/minimumZoomScale*100)
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer
    }
    func viewForZooming(in scrollView:UIScrollView)->UIView? { canvas }
    func scrollViewDidZoom(_ scrollView:UIScrollView){ centerBoard(); onScale?(zoomScale) }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        canvas.contentScaleFactor=max(1,traitCollection.displayScale*scale); canvas.setNeedsDisplay()
    }
    func fit(){ setZoomScale(minimumZoomScale,animated:false); contentOffset=CGPoint(x:-contentInset.left,y:-contentInset.top) }
    func magnify(){ zoom(at:canvas.selected.map { CGPoint(x:canvas.rect($0).midX,y:canvas.rect($0).midY) } ?? CGPoint(x:BoardCanvas.side/2,y:BoardCanvas.side/2),scale:min(maximumZoomScale,zoomScale*1.6)) }
    private func zoom(at point:CGPoint,scale:CGFloat){ zoom(to:CGRect(x:point.x-bounds.width/scale/2,y:point.y-bounds.height/scale/2,width:bounds.width/scale,height:bounds.height/scale),animated:false) }
    private func square(at point:CGPoint)->Int? {
        let col=Int(floor((point.x-BoardCanvas.margin)/BoardCanvas.cell)), row=Int(floor((point.y-BoardCanvas.margin)/BoardCanvas.cell))
        return (0..<15).contains(col) && (0..<15).contains(row) ? row*15+col : nil
    }
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool {
        if let tap=gestureRecognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2, touch.tapCount == 1 {
            doubleWasSelected = square(at:touch.location(in:canvas)).map { $0 == canvas.selected } ?? false
        }
        return true
    }
    @objc private func tapped(_ gesture:UITapGestureRecognizer){
        if let index=square(at:gesture.location(in:canvas)) { canvas.choose(index) }
    }
    @objc private func doubled(_ gesture:UITapGestureRecognizer){
        if doubleWasSelected, square(at:gesture.location(in:canvas)) == canvas.selected { canvas.onToggleDirection?() }
    }
}
