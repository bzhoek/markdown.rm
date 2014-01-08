class MarkdownTextStorage < NSTextStorage

  def init
    super
    @backingStore = NSMutableAttributedString.new
    createStyles
    self
  end

  def createStyles
    @normal = {NSFontAttributeName => NSFont.fontWithName("Avenir Next", size: 17)}

    @paragraphs = {
      "^#\\s" => NSFontManager.sharedFontManager.fontWithFamily("Avenir Next", traits: NSBoldFontMask, weight: 0, size: 23),
      "^##\\s" => NSFontManager.sharedFontManager.fontWithFamily("Avenir Next", traits: NSBoldFontMask, weight: 0, size: 21),
      "^###\\s" => NSFontManager.sharedFontManager.fontWithFamily("Avenir Next", traits: NSBoldFontMask, weight: 0, size: 19),
      "^####\\s" => NSFontManager.sharedFontManager.fontWithFamily("Avenir Next", traits: NSBoldFontMask, weight: 0, size: 17),
      "^\\t" => NSFontManager.sharedFontManager.fontWithFamily("Menlo", traits: 0, weight: 0, size: 17)
    }

    @replacements = {
      "(\\*\\w+(\\s\\w+)*\\*)\\s" => NSFontManager.sharedFontManager.fontWithFamily("Avenir Next", traits: NSBoldFontMask, weight: 0, size: 17),
      "(_\\w+(\\s\\w+)*_)\\s" => NSFontManager.sharedFontManager.fontWithFamily("Avenir Next", traits: NSItalicFontMask, weight: 0, size: 17),
      "(`\\w+(\\s\\w+)*`)\\s" => NSFontManager.sharedFontManager.fontWithFamily("Menlo", traits: 0, weight: 0, size: 17)
    }
  end

  def string
    @backingStore.string
  end

  def attributesAtIndex(location, effectiveRange: range)
    @backingStore.attributesAtIndex(location, effectiveRange: range)
  end

  def replaceCharactersInRange(range, withString: str)
    puts "replaceCharactersInRange: #{NSStringFromRange(range)} withString: #{str}"

    groupEdits do
      @backingStore.replaceCharactersInRange(range, withString: str)
      self.edited(NSTextStorageEditedCharacters | NSTextStorageEditedAttributes, range: range, changeInLength: str.length - range.length)
    end
  end

  def setAttributes(attrs, range: range)
    puts "setAttributes: #{attrs} range:#{NSStringFromRange(range)}"

    groupEdits do
      @backingStore.setAttributes(attrs, range: range)
      self.edited(NSTextStorageEditedAttributes, range: range, changeInLength: 0)
    end
  end

  def processEditing
    puts "edited: #{self.editedRange.inspect}"
    super
    lineRange = NSUnionRange(self.editedRange, @backingStore.string.lineRangeForRange(NSMakeRange(self.editedRange.location, 0)))
    self.applyStylesToRange(lineRange)
    # process next line in case it was split
    if lineRange.location + lineRange.length + 1 < @backingStore.string.length
      lineRange = @backingStore.string.lineRangeForRange(NSMakeRange(lineRange.location + lineRange.length + 1, 0))
      self.applyStylesToRange(lineRange)
    end
  end

  def groupEdits
    self.beginEditing
    yield if block_given?
    self.endEditing
  end

  def applyStylesToRange(searchRange)
    puts "search: #{searchRange.inspect}: #{@backingStore.string.substringWithRange(searchRange)}"

    self.addAttributes(@normal, range: searchRange)
    @paragraphs.each do |expression, font|
      regex = NSRegularExpression.regularExpressionWithPattern(expression, options: 0, error: nil)
      regex.enumerateMatchesInString(@backingStore.string, options: 0, range: searchRange,
        usingBlock: lambda do |match, flags, stop|
          self.addAttributes({NSFontAttributeName => font}, range: searchRange)
        end
      )
    end

    @replacements.each do |expression, font|
      regex = NSRegularExpression.regularExpressionWithPattern(expression, options: 0, error: nil)
      regex.enumerateMatchesInString(@backingStore.string, options: 0, range: searchRange,
        usingBlock: lambda do |match, flags, stop|
          matchRange = match.rangeAtIndex(1)
          self.addAttributes({NSFontAttributeName => font}, range: matchRange)
          if NSMaxRange(matchRange) + 1 < self.length
            self.addAttributes(@normal, range: NSMakeRange(NSMaxRange(matchRange) + 1, 1))
          end
        end
      )
    end

  end


end

class AppDelegate

  def applicationDidFinishLaunching(notification)
    buildMenu
    buildWindow
  end

  def buildWindow
    @mainWindow = NSWindow.alloc.initWithContentRect([[240, 180], [480, 360]],
      styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask,
      backing: NSBackingStoreBuffered,
      defer: false)
    @mainWindow.title = NSBundle.mainBundle.infoDictionary['CFBundleName']
    @mainWindow.orderFrontRegardless

    @textView = buildTextView
    @mainWindow.contentView.addSubview(@textView)
    @mainWindow.makeFirstResponder(@textView)
  end


  def buildTextView
    attrs = {NSFontAttributeName => NSFont.fontWithName("Avenir Next", size: 17)}
    string = NSAttributedString.alloc.initWithString("# Start\nHello, _world_ , say something *bold* and `quoted` .", attributes: attrs)

    bounds = @mainWindow.contentView.bounds

    containerSize = CGSizeMake(bounds.size.width, CGFLOAT_MAX)
    textContainer = NSTextContainer.alloc.initWithContainerSize(containerSize)
    textContainer.widthTracksTextView = true

    layoutManager = NSLayoutManager.alloc.init
    layoutManager.addTextContainer(textContainer)

    @textStorage = MarkdownTextStorage.alloc.init
    @textStorage.appendAttributedString(string)
    @textStorage.addLayoutManager(layoutManager)

    textView = NSTextView.alloc.initWithFrame(bounds, textContainer: textContainer)
    textView.allowsUndo = true
    textView.setSelectedRange(NSMakeRange(2, 0))
    textView
  end

end
