import UIKit

func stack(_ axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 12) -> UIStackView {
    let s = UIStackView(); s.axis=axis; s.spacing=spacing; return s
}
func label(_ text: String = "", style: UIFont.TextStyle = .body) -> UILabel {
    let l=UILabel(); l.text=text; l.font = .preferredFont(forTextStyle:style); l.adjustsFontForContentSizeCategory=true; l.numberOfLines=0; return l
}
func button(_ title: String, symbol: String? = nil, action: @escaping () -> Void) -> UIButton {
    var config=UIButton.Configuration.glass(); config.title=title
    if let symbol { config.image=UIImage(systemName:symbol); config.imagePadding=6 }
    let b=UIButton(configuration:config,primaryAction:UIAction { _ in action() }); b.heightAnchor.constraint(greaterThanOrEqualToConstant:44).isActive=true; return b
}
// UITextField remains the native editor; UIVisualEffectView supplies Apple's glass surface.
func glassInput(_ field: UITextField) -> UIView {
    let surface=UIVisualEffectView(effect:UIGlassEffect(style:.regular))
    surface.layer.cornerRadius=22; surface.layer.cornerCurve = .continuous; surface.clipsToBounds=true
    field.translatesAutoresizingMaskIntoConstraints=false
    surface.contentView.addSubview(field)
    NSLayoutConstraint.activate([
        field.leadingAnchor.constraint(equalTo:surface.contentView.leadingAnchor,constant:16),
        field.trailingAnchor.constraint(equalTo:surface.contentView.trailingAnchor,constant:-16),
        field.topAnchor.constraint(equalTo:surface.contentView.topAnchor,constant:4),
        field.bottomAnchor.constraint(equalTo:surface.contentView.bottomAnchor,constant:-4)
    ])
    return surface
}
final class GameController: UIViewController, UITextFieldDelegate {
    private let store=GameStore()
    private let gameDictionary=UISegmentedControl(items:["NASPA","Collins"])
    private var game: TrackedGame?
    private var dictionary: WordDictionary?
    private let board=ZoomBoard()
    private let scores=stack(.horizontal,spacing:8)
    private var keyboardVisible=false
    private let turnLabel=label(style:.headline)
    private let boardControls=stack(.horizontal,spacing:8)
    private var placementError: String?
    private let word=UITextField()
    private let direction=UISegmentedControl(items:["Across →","Down ↓"])
    private let editor=stack(spacing:8)
    private var playButton: UIButton!
    private var start=112
    private var result: PlayResult?
    private var draftEntry=BoardDraft()
    private var loadError: String?
    private let empty=stack(spacing:18)
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title="Word Check"
        gameDictionary.accessibilityIdentifier="gameDictionary"
        gameDictionary.widthAnchor.constraint(equalToConstant:220).isActive=true
        gameDictionary.addTarget(self,action:#selector(switchDictionary),for:.valueChanged)
        view.backgroundColor = .systemBackground
        view.tintColor = UIColor { $0.userInterfaceStyle == .dark ? .systemMint : UIColor(red:0.1,green:0.32,blue:0.26,alpha:1) }
        do { dictionary=try WordDictionary(); game=try store.load() } catch { loadError=error.localizedDescription }
        if ProcessInfo.processInfo.arguments.contains("-freshGame") { game=nil }
        let root=stack(spacing:10); root.translatesAutoresizingMaskIntoConstraints=false; view.addSubview(root)
        NSLayoutConstraint.activate([root.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),root.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:16),root.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-16),root.bottomAnchor.constraint(equalTo:view.keyboardLayoutGuide.topAnchor,constant:-8)])
        scores.distribution = .fillEqually
        root.addArrangedSubview(scores)
        let controls=boardControls; controls.alignment = .center
        controls.addArrangedSubview(turnLabel)
        root.addArrangedSubview(controls)
        board.setContentHuggingPriority(.defaultLow,for:.vertical)
        board.heightAnchor.constraint(greaterThanOrEqualToConstant:44).isActive=true
        root.addArrangedSubview(board)
        board.canvas.onSelect = { [weak self] index in
            guard let self, self.game?.finished == false else { return }
            self.start=index; self.board.canvas.selected=index; self.updatePreview()
        }
        board.canvas.onToggleDirection = { [weak self] in
            guard let self, self.game?.finished == false else { return }
            self.direction.selectedSegmentIndex = 1 - self.direction.selectedSegmentIndex
            self.changedDirection()
        }
        root.addArrangedSubview(editor)
        let entry=stack(.horizontal,spacing:10); entry.alignment = .center
        word.placeholder="Word"; word.font = .preferredFont(forTextStyle:.title3)
        word.borderStyle = .none; word.autocapitalizationType = .allCharacters; word.autocorrectionType = .no; word.spellCheckingType = .no; word.keyboardType = .asciiCapable; word.returnKeyType = .done
        word.accessibilityIdentifier="moveWord"; word.accessibilityLabel="Word to place"
        word.delegate=self; word.addTarget(self,action:#selector(changed),for:.editingChanged)
        word.heightAnchor.constraint(greaterThanOrEqualToConstant:44).isActive=true
        entry.addArrangedSubview(glassInput(word))
        let cancel=button("",symbol:"xmark") { [weak self] in self?.clearDraft() }; cancel.accessibilityLabel="Clear draft"; cancel.widthAnchor.constraint(equalToConstant:44).isActive=true; cancel.heightAnchor.constraint(equalToConstant:44).isActive=true; cancel.configuration?.cornerStyle = .capsule; cancel.configuration?.contentInsets = .zero
        entry.addArrangedSubview(cancel); editor.addArrangedSubview(entry)
        let selectors=stack(.horizontal,spacing:8); selectors.alignment = .center
        direction.selectedSegmentIndex=0; direction.accessibilityIdentifier="moveDirection"; direction.addTarget(self,action:#selector(changedDirection),for:.valueChanged)
        selectors.addArrangedSubview(direction)
        playButton=button("Play") { [weak self] in self?.commit() }; playButton.accessibilityIdentifier="playMove"; playButton.widthAnchor.constraint(equalToConstant:112).isActive=true
        selectors.addArrangedSubview(playButton); editor.addArrangedSubview(selectors)
        empty.alignment = .center; empty.translatesAutoresizingMaskIntoConstraints=false; view.addSubview(empty)
        let new=button("New game",symbol:"plus") { [weak self] in self?.newGame() }; new.accessibilityIdentifier="newGame"
        empty.addArrangedSubview(new)
        NSLayoutConstraint.activate([empty.centerXAnchor.constraint(equalTo:view.centerXAnchor),empty.centerYAnchor.constraint(equalTo:view.safeAreaLayoutGuide.centerYAnchor),empty.widthAnchor.constraint(lessThanOrEqualTo:view.widthAnchor,constant:-40)])
        root.isHidden = game == nil
        root.accessibilityIdentifier="gameContent"
        NotificationCenter.default.addObserver(self,selector:#selector(keyboardChanged(_:)),name:UIResponder.keyboardWillChangeFrameNotification,object:nil)
        refresh()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let error=loadError { loadError=nil; alert("Unable to load",error) }
    }
    @objc private func keyboardChanged(_ notification: Notification) {
        guard let screenFrame=notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {return}
        let frame=view.convert(screenFrame,from:nil)
        keyboardVisible=frame.intersects(view.bounds) && frame.minY < view.bounds.maxY-80
        scores.isHidden=keyboardVisible
        boardControls.isHidden=game?.finished != true
        view.layoutIfNeeded()
    }
    private func refresh() {
        empty.isHidden = game != nil
        navigationItem.titleView = game == nil ? nil : gameDictionary
        gameDictionary.selectedSegmentIndex=game?.lexicon ?? 0
        view.subviews.first(where:{$0.accessibilityIdentifier=="gameContent"})?.isHidden = game == nil
        scores.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let game {
            for i in game.names.indices {
                let l=label("\(game.names[i])\n\(game.scores[i])",style:.headline); l.textAlignment = .center; l.numberOfLines=2; l.accessibilityIdentifier="score-\(i)"
                let active = !game.finished && game.currentPlayer == i
                l.textColor = active ? UIColor { $0.userInterfaceStyle == .dark ? .black : .white } : .label
                l.backgroundColor = active ? UIColor { $0.userInterfaceStyle == .dark ? .systemMint : UIColor(red:0.10,green:0.32,blue:0.26,alpha:1) } : .secondarySystemBackground
                l.accessibilityValue = active ? "Current turn" : nil
                l.layer.cornerRadius=12; l.clipsToBounds=true; l.heightAnchor.constraint(greaterThanOrEqualToConstant:60).isActive=true
                scores.addArrangedSubview(l)
            }
            if game.finished {
                let high=game.scores.max() ?? 0; let winners=game.names.indices.filter { game.scores[$0] == high }.map { game.names[$0] }
                turnLabel.text = winners.count == 1 ? "\(winners[0]) wins" : "Tie · \(winners.joined(separator:", "))"
            } else { turnLabel.text="\(game.names[game.currentPlayer])’s turn" }
            turnLabel.accessibilityIdentifier="currentTurn"
            boardControls.isHidden = !game.finished
            board.canvas.tiles=game.board
            editor.isHidden=game.finished
        }
        let menu=UIMenu(children:[
            UIAction(title:"Check a word",image:UIImage(systemName:"checkmark.circle")) { [weak self] _ in
                self?.view.endEditing(true)
                self?.present(UINavigationController(rootViewController:CheckerController(dictionary:self?.dictionary)),animated:true)
            },
            UIAction(title:"FAQ",image:UIImage(systemName:"questionmark.circle")) { [weak self] _ in
                self?.word.resignFirstResponder()
                self?.present(UINavigationController(rootViewController:FAQController()),animated:true)
            },
            UIAction(title:"Challenge last play",image:UIImage(systemName:"hand.raised"),attributes:game?.canChallenge == true ? [] : .disabled) { [weak self] _ in self?.challenge() },
            UIAction(title:"Pass turn",image:UIImage(systemName:"forward.end"),attributes:game == nil || game?.finished == true ? .disabled : []) { [weak self] _ in self?.skip(false) },
            UIAction(title:"Exchange tiles",image:UIImage(systemName:"arrow.triangle.2.circlepath"),attributes:game == nil || game?.finished == true ? .disabled : []) { [weak self] _ in self?.skip(true) },
            UIAction(title:"Undo last turn",image:UIImage(systemName:"arrow.uturn.backward"),attributes:game?.turns.isEmpty != false ? .disabled : []) { [weak self] _ in self?.undo() },
            UIAction(title:"History",image:UIImage(systemName:"clock")) { [weak self] _ in self?.history() },
            UIAction(title:"Finish game",image:UIImage(systemName:"flag.checkered"),attributes:game == nil || game?.finished == true ? .disabled : []) { [weak self] _ in self?.finish() },
            UIAction(title:"New game",image:UIImage(systemName:"plus")) { [weak self] _ in self?.newGame() }
        ])
        navigationItem.rightBarButtonItem=UIBarButtonItem(image:UIImage(systemName:"ellipsis"),menu:menu)
        navigationItem.rightBarButtonItem?.accessibilityIdentifier="gameMenu"
        navigationItem.rightBarButtonItem?.accessibilityLabel="Game actions"
        updatePreview()
    }
    @objc private func switchDictionary(){
        guard var next=game else{return}
        next.lexicon=gameDictionary.selectedSegmentIndex
        if persist(next){updatePreview()} else {gameDictionary.selectedSegmentIndex=game?.lexicon ?? 0}
    }
    @objc private func changed(){ updatePreview() }
    @objc private func changedDirection(){ updatePreview() }
    private func updatePreview() {
        word.text=draftEntry.display(board:board.canvas.tiles,start:start,vertical:direction.selectedSegmentIndex==1).text
        board.canvas.vertical = direction.selectedSegmentIndex == 1
        result=nil; placementError=nil; board.canvas.draft=[]
        let text=word.text ?? ""
        playButton?.isEnabled = game != nil && !text.isEmpty
        playButton?.configuration?.title="Play"
        guard game != nil, !text.isEmpty else { return }
        let currentBoard=board.canvas.tiles
        do {
            let typed=try TypedPlay.parse(word.text ?? "")
            for offset in typed.blanks {
                let index=start+offset*(direction.selectedSegmentIndex==1 ? 15 : 1)
                if index<225, currentBoard[index] != nil { throw RuleError("Existing tiles keep their original value. Use ? only for a new blank tile.") }
            }
            guard !typed.word.contains("?") else { throw RuleError("Assign a letter to each blank before playing.") }
            let result=try BoardRules.evaluate(board:currentBoard,word:typed.word,start:start,vertical:direction.selectedSegmentIndex==1,blanks:typed.blanks) { _ in true }
            self.result=result; board.canvas.draft=result.placements
            playButton.configuration?.title="Play · \(result.score)"
        } catch {
            placementError=error.localizedDescription
            if let prefix=try? TypedPlay.parse(text) {
                let letters=Array(prefix.word).map(String.init)
                board.canvas.draft=letters.enumerated().compactMap { offset,letter in
                    guard (direction.selectedSegmentIndex==1 ? start/15 : start%15)+offset<15 else { return nil }
                    let index=start+offset*(direction.selectedSegmentIndex==1 ? 15 : 1)
                    guard currentBoard[index] == nil else { return nil }
                    return Placement(index:index,tile:Tile(letter:letter,blank:prefix.blanks.contains(offset) || letter == "?"))
                }
            }
        }
    }
    private func persist(_ next: TrackedGame) -> Bool {
        do { try store.save(next); game=next; return true } catch { alert("Couldn’t save game", "Your turn has not been changed. \(error.localizedDescription)"); return false }
    }
    private func clearDraft(){ draftEntry=BoardDraft(); word.text=""; word.resignFirstResponder(); board.canvas.selected=nil; updatePreview() }
    private func commit(){
        if let index=Array(draftEntry.input).firstIndex(of:"?") { assignBlank(at:index); return }
        guard let result else { if let placementError { alert("Check placement",placementError) }; return }
        guard var next=game else { return }; next.play(result)
        if persist(next) { clearDraft(); refresh(); UIAccessibility.post(notification:.announcement,argument:"\(result.score) points. \(next.names[next.currentPlayer])’s turn.") }
    }
    private func assignBlank(at index:Int) {
        word.resignFirstResponder()
        let prompt=UIAlertController(title:"Blank letter",message:"Which letter does this blank represent?",preferredStyle:.alert)
        prompt.addTextField { field in
            field.placeholder="A–Z"; field.autocapitalizationType = .allCharacters; field.autocorrectionType = .no
            field.keyboardType = .asciiCapable; field.accessibilityIdentifier="blankLetter"
        }
        prompt.addAction(UIAlertAction(title:"Cancel",style:.cancel))
        prompt.addAction(UIAlertAction(title:"Continue",style:.default) { [weak self,weak prompt] _ in
            guard let self else { return }
            let letter=(prompt?.textFields?.first?.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
            guard letter.utf8.count == 1, let byte=letter.utf8.first, (65...90).contains(byte) else {
                self.assignBlank(at:index); return
            }
            var chars=Array(self.draftEntry.input); chars[index]=Character(letter.lowercased())
            self.draftEntry.input=String(chars); self.updatePreview(); self.commit()
        })
        present(prompt,animated:true)
    }
    private func skip(_ exchange: Bool){
        guard let game, !game.finished else { return }
        confirm(nil,exchange ? "Exchange tiles?" : "Pass turn", action:exchange ? "Exchange" : "Pass") { [weak self] in
            guard let self, var next=self.game else { return }; next.skip(exchange:exchange); if self.persist(next){self.clearDraft();self.refresh()}
        }
    }
    private func undo(){
        guard let game, let last=game.turns.last else { return }
        confirm("Undo \(last.title)?","This restores the board, scores, and player’s turn.",action:"Undo") { [weak self] in
            guard let self,var next=self.game else{return}; next.turns.removeLast(); if self.persist(next){self.clearDraft();self.refresh()}
        }
    }
    private func newGame(){
        let open={ [weak self] in
            guard let self else{return}; self.word.resignFirstResponder()
            let setup=SetupController(); setup.onStart={ [weak self] game in guard let self else{return}; if self.persist(game){self.dismiss(animated:true);self.start=112;self.clearDraft();self.refresh();self.board.fit()} }
            self.present(UINavigationController(rootViewController:setup),animated:true)
        }
        if game != nil { confirm("Start a new game?","The current game will be replaced. Its scores and history will be removed from this device.",action:"New game",handler:open) } else { open() }
    }
    private func finish(){
        guard let game else{return}; word.resignFirstResponder()
        let form=FinishController(game:game)
        form.onFinish={ [weak self] racks,out in
            guard let self,var next=self.game else{return}
            do { try next.finish(racks:racks,wentOut:out); if self.persist(next){self.dismiss(animated:true);self.clearDraft();self.refresh()} } catch { form.showError(error.localizedDescription) }
        }
        present(UINavigationController(rootViewController:form),animated:true)
    }
    private func challenge() {
        guard game?.canChallenge == true, let dictionary else { return }
        confirm(nil, "Challenge the previous play? An unsuccessful challenge forfeits your turn.", action:"Challenge") { [weak self] in
            guard let self, var next=self.game else { return }
            do {
                let won=try next.challenge { dictionary.contains($0,in:Lexicon(rawValue:$1) ?? .naspa) }
                if self.persist(next) {
                    self.clearDraft(); self.refresh()
                    self.alert(won ? "Challenge successful" : "Challenge unsuccessful", won ? "The tiles and points have been removed. It’s still your turn." : "The play stands. Your turn is skipped.")
                }
            } catch { self.alert("Couldn’t challenge",error.localizedDescription) }
        }
    }
    private func history(){
        guard let game else{return}
        word.resignFirstResponder()
        present(UINavigationController(rootViewController:HistoryController(game:game)),animated:true)
    }
    private func alert(_ title:String,_ message:String){let a=UIAlertController(title:title,message:message,preferredStyle:.alert);a.addAction(UIAlertAction(title:"OK",style:.default));present(a,animated:true)}
    private func confirm(_ title:String?,_ message:String,action:String,handler:@escaping()->Void){word.resignFirstResponder();let a=UIAlertController(title:title,message:message,preferredStyle:.alert);a.addAction(UIAlertAction(title:"Cancel",style:.cancel));a.addAction(UIAlertAction(title:action,style:.default){_ in handler()});present(a,animated:true)}
    func textField(_ textField:UITextField,shouldChangeCharactersIn range:NSRange,replacementString string:String)->Bool {
        guard string.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || $0 == 63 }) else { return false }
        let displayed=draftEntry.display(board:board.canvas.tiles,start:start,vertical:direction.selectedSegmentIndex==1)
        let caret=draftEntry.edit(range:range,replacement:string,display:displayed)
        updatePreview()
        let updated=draftEntry.display(board:board.canvas.tiles,start:start,vertical:direction.selectedSegmentIndex==1)
        let offset=updated.sources.firstIndex(where: { $0.map { $0 >= caret } ?? false }) ?? updated.sources.count
        if let position=word.position(from:word.beginningOfDocument,offset:offset) { word.selectedTextRange=word.textRange(from:position,to:position) }
        return false
    }
    func textFieldShouldReturn(_ textField:UITextField)->Bool { textField.resignFirstResponder();return false }
}

class FormController: UIViewController {
    let content=stack(spacing:18)
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor = .systemBackground
        let scroll=UIScrollView();scroll.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(scroll);scroll.keyboardDismissMode = .interactive
        content.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(content)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),scroll.bottomAnchor.constraint(equalTo:view.keyboardLayoutGuide.topAnchor),scroll.leadingAnchor.constraint(equalTo:view.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.trailingAnchor),content.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:20),content.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-20),content.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:20),content.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-20),content.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-40)])
        navigationItem.leftBarButtonItem=UIBarButtonItem(systemItem:.cancel,primaryAction:UIAction{[weak self] _ in self?.dismiss(animated:true)})
    }
    func field(_ placeholder:String)->UITextField{let f=UITextField();f.borderStyle = .none;f.placeholder=placeholder;f.font = .preferredFont(forTextStyle:.body);f.heightAnchor.constraint(greaterThanOrEqualToConstant:48).isActive=true;return f}
    func showError(_ text:String){let a=UIAlertController(title:"Check the details",message:text,preferredStyle:.alert);a.addAction(UIAlertAction(title:"OK",style:.default));present(a,animated:true)}
}
final class SetupController: FormController {
    var onStart:((TrackedGame)->Void)?
    private let count=UISegmentedControl(items:["2 players","3 players","4 players"])
    private let lexicon=UISegmentedControl(items:["NASPA","Collins"])
    private var names=[UITextField]()
    override func viewDidLoad(){
        super.viewDidLoad();title="New game"
        count.selectedSegmentIndex=0;count.accessibilityIdentifier="playerCount";count.addTarget(self,action:#selector(update),for:.valueChanged);content.addArrangedSubview(count)
        for i in 0..<4 {let f=field("Player \(i+1)");f.accessibilityIdentifier="playerName-\(i)";f.autocapitalizationType = .words;names.append(f);content.addArrangedSubview(glassInput(f))}
        content.addArrangedSubview(label("Dictionary",style:.headline));lexicon.accessibilityIdentifier="setupDictionary";lexicon.selectedSegmentIndex=UserDefaults.standard.integer(forKey:"lexicon")==1 ? 1:0;content.addArrangedSubview(lexicon)
        let start=button("Start game") { [weak self] in self?.start() };start.accessibilityIdentifier="startGame";content.addArrangedSubview(start);update()
    }
    @objc private func update(){for i in 0..<4{names[i].superview?.superview?.isHidden=i>=count.selectedSegmentIndex+2}}
    private func start(){
        let players=names.prefix(count.selectedSegmentIndex+2).enumerated().map { i,f in let s=(f.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines);return s.isEmpty ? "Player \(i+1)" : String(s.prefix(20)) }
        guard Set(players.map{$0.lowercased()}).count==players.count else {showError("Give each player a different name.");return}
        onStart?(TrackedGame(names:players,lexicon:lexicon.selectedSegmentIndex))
    }
}
final class FinishController: FormController {
    let game:TrackedGame
    var onFinish:(([String],Int?)->Void)?
    private var racks=[UITextField]()
    private var out:UISegmentedControl!
    init(game:TrackedGame){self.game=game;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override func viewDidLoad(){
        super.viewDidLoad();title="Finish game"
        content.addArrangedSubview(label("Remaining tiles",style:.title2))
        for i in game.names.indices {content.addArrangedSubview(label(game.names[i],style:.headline));let f=field("Remaining letters");f.autocapitalizationType = .allCharacters;f.autocorrectionType = .no;f.keyboardType = .asciiCapable;f.accessibilityIdentifier="rack-\(i)";racks.append(f);content.addArrangedSubview(glassInput(f))}
        content.addArrangedSubview(label("Who went out?",style:.headline))
        out=UISegmentedControl(items:["Nobody"]+game.names);out.selectedSegmentIndex=0;out.accessibilityIdentifier="wentOut";content.addArrangedSubview(out)
        let finish=button("Finish & score racks") { [weak self] in guard let self else{return};self.onFinish?(self.racks.map{$0.text ?? ""},self.out.selectedSegmentIndex==0 ? nil:self.out.selectedSegmentIndex-1) };finish.accessibilityIdentifier="finishGame";content.addArrangedSubview(finish)
    }
}

final class HistoryController: UITableViewController {
    private let game: TrackedGame
    init(game: TrackedGame) { self.game=game; super.init(style:.insetGrouped) }
    required init?(coder:NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); title="History"
        navigationItem.rightBarButtonItem=UIBarButtonItem(systemItem:.done,primaryAction:UIAction { [weak self] _ in self?.dismiss(animated:true) })
        tableView.register(UITableViewCell.self,forCellReuseIdentifier:"turn")
        tableView.allowsSelection=false
        if game.turns.isEmpty {
            var empty=UIContentUnavailableConfiguration.empty(); empty.text="No turns yet"; empty.image=UIImage(systemName:"clock")
            contentUnavailableConfiguration=empty
        }
    }
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int { game.turns.count }
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let index=game.turns.count-1-indexPath.row, turn=game.turns[index]
        let cell=tableView.dequeueReusableCell(withIdentifier:"turn",for:indexPath)
        var content=cell.defaultContentConfiguration()
        let challenged=game.turns.contains { $0.kind == "challengeWon" && $0.challengedTurn == index }
        content.text=turn.title
        content.textProperties.font = .preferredFont(forTextStyle:.headline)
        content.textProperties.color=challenged ? .secondaryLabel : .label
        var detail=game.names[turn.player]
        if challenged { detail += " · Challenged successfully" }
        else if turn.kind == "challengeLost" { detail += " · Turn forfeited" }
        let points=turn.changes.enumerated().filter { $0.element != 0 }.map { "\(game.names[$0.offset]) \($0.element > 0 ? "+" : "")\($0.element)" }.joined(separator:" · ")
        if !points.isEmpty { detail += "\n" + points }
        content.secondaryText=detail; content.secondaryTextProperties.color = .secondaryLabel
        content.image=UIImage(systemName:turn.kind == "play" ? (challenged ? "arrow.uturn.backward.circle" : "textformat.abc") : turn.kind.hasPrefix("challenge") ? "hand.raised" : turn.kind == "finish" ? "flag.checkered" : "forward.end")
        content.imageProperties.tintColor = .secondaryLabel
        cell.contentConfiguration=content
        return cell
    }
}

final class FAQController: UITableViewController {
    private let entries: [(String,String)] = [
        ("How do I enter a blank?", "Type ? in place of a letter: C?T uses a blank in the middle. Each ? occupies one square immediately, and existing letters are skipped automatically. When you press Play, choose the letter each blank represents. A yellow 0 badge identifies blanks on the board. Each scores zero and keeps its assigned letter for the rest of the game."),
        ("How do I use letters already on the board?", "Type only your new letters. Existing letters in the selected direction are included automatically. Backspace skips board letters and removes your draft tiles. Use ? for a new blank; existing blanks keep their zero value automatically."),
        ("How do I change direction or zoom?", "Double-tap the selected square to switch Across and Down, or use the direction control. Pinch to zoom and drag to move around the board."),
        ("Why aren’t words checked when I play?", "This is a score tracker. Plays are recorded without dictionary hints. On the next turn, choose Challenge last play to check every word the previous move formed."),
        ("What happens after a challenge?", "If any formed word is absent from the dictionary, the play’s new tiles and points are removed and the challenger keeps their turn. Otherwise, the challenger loses their turn. History keeps the original play and the result."),
        ("Can we switch dictionaries?", "Switch NASPA or Collins at the top at any time. A challenge uses the dictionary selected when the challenged play was made."),
        ("How do scoring, passing, and exchanges work?", "Scores include crosswords, bonuses on newly covered squares, and 50 points for seven new tiles. Passing or exchanging records a zero-point turn. Keep racks and the bag on the table; confirm at least seven tiles remain in the bag before exchanging."),
        ("Can I correct a mistake or finish a game?", "Undo last turn restores the previous board, scores, and turn, including a challenge. Finish game applies remaining-rack deductions; use ? for an unplayed blank. Games save automatically on this device.")
    ]
    init(){super.init(style:.insetGrouped)}
    required init?(coder:NSCoder){fatalError()}
    override func viewDidLoad(){
        super.viewDidLoad();title="FAQ";tableView.allowsSelection=false
        tableView.register(UITableViewCell.self,forCellReuseIdentifier:"faq")
        navigationItem.rightBarButtonItem=UIBarButtonItem(systemItem:.done,primaryAction:UIAction{[weak self] _ in self?.dismiss(animated:true)})
    }
    override func numberOfSections(in tableView:UITableView)->Int { entries.count }
    override func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int { 1 }
    override func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=tableView.dequeueReusableCell(withIdentifier:"faq",for:indexPath)
        var content=cell.defaultContentConfiguration()
        content.text=entries[indexPath.section].0;content.textProperties.font = .preferredFont(forTextStyle:.headline)
        content.secondaryText=entries[indexPath.section].1;content.secondaryTextProperties.font = .preferredFont(forTextStyle:.body)
        content.secondaryTextProperties.color = .secondaryLabel;content.secondaryTextProperties.numberOfLines=0
        content.textToSecondaryTextVerticalPadding=8;cell.contentConfiguration=content;return cell
    }
}
