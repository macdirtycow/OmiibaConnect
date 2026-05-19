//
//  ViewController.mm
//  Omiiba Connect
//

#import "ViewController.h"

static const CGFloat kContentWidth = 400;

static NSStackView* OmiibaVerticalStack(CGFloat spacing) {
    NSStackView* stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

static NSStackView* OmiibaHorizontalStack(CGFloat spacing) {
    NSStackView* stack = [[NSStackView alloc] init];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.alignment = NSLayoutAttributeCenterY;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

static void OmiibaPrepareForAutoLayout(NSView* view) {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSView* subview in view.subviews) {
        OmiibaPrepareForAutoLayout(subview);
    }
}

static void OmiibaConstrainWidth(NSView* view, CGFloat width) {
    OmiibaPrepareForAutoLayout(view);
    if (width > 0) {
        [view.widthAnchor constraintEqualToConstant:width].active = YES;
    }
}

static void OmiibaAddSection(NSStackView* root, NSString* title, NSView* content, CGFloat contentWidth) {
    NSTextField* header = [NSTextField labelWithString:title];
    header.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    header.textColor = NSColor.secondaryLabelColor;
    OmiibaPrepareForAutoLayout(header);
    [root addArrangedSubview:header];

    OmiibaConstrainWidth(content, contentWidth);
    [root addArrangedSubview:content];
}

@implementation ViewController {
    NSInteger _refreshGeneration;
    dispatch_queue_t _bluetoothQueue;
    BOOL _refreshInProgressFlag;
    NSInteger _ancDebounceGeneration;
    NSInteger _eqDebounceGeneration;
}
@synthesize connectedLabel, connectButton, ANCSlider, ANCValueLabel, focusOnVoice, ANCEnabled, ANCValuePrefixLabel, virtualSoundLabel, soundPositionLabel, surroundLabel, soundPosition, surround;
@synthesize batteryLabel, codecLabel, firmwareLabel, eqPopup, touchSensorCheckbox, voiceGuidanceCheckbox, refreshButton;
@synthesize batteryIndicator, connectionIndicator, refreshSpinner, scrollView, modelLabel;

- (void)viewDidLoad {
    [super viewDidLoad];
    _bluetoothQueue = dispatch_queue_create("dev.omiiba.connect.bluetooth", DISPATCH_QUEUE_SERIAL);
    std::unique_ptr<IBluetoothConnector> connector = std::make_unique<MacOSBluetoothConnector>();
    bt = BluetoothWrapper(std::move(connector));
    statusItem = [NSStatusBar.systemStatusBar statusItemWithLength: -1];
    statusItem.button.image = [NSImage imageNamed:@"NSRefreshTemplate"];
    [statusItem setTarget:self];
    [statusItem setAction:@selector(statusItemClick:)];

    [self buildExtendedControls];
    [self setupModernLayout];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    NSWindow* window = self.view.window;
    if (window) {
        [window setContentMinSize:NSMakeSize(480, 640)];
        [window setContentSize:NSMakeSize(480, 680)];
        [window center];
    }
}

- (void)buildExtendedControls {
    self.batteryIndicator = [[NSLevelIndicator alloc] init];
    self.batteryIndicator.levelIndicatorStyle = NSLevelIndicatorStyleContinuousCapacity;
    self.batteryIndicator.minValue = 0;
    self.batteryIndicator.maxValue = 100;
    self.batteryIndicator.doubleValue = 0;
    self.batteryIndicator.controlSize = NSControlSizeRegular;

    self.batteryLabel = [NSTextField labelWithString:@"—"];
    self.batteryLabel.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];

    self.codecLabel = [NSTextField labelWithString:@"Codec: —"];
    self.codecLabel.font = [NSFont systemFontOfSize:12];
    self.codecLabel.textColor = NSColor.secondaryLabelColor;

    self.firmwareLabel = [NSTextField labelWithString:@"Firmware: —"];
    self.firmwareLabel.font = [NSFont systemFontOfSize:12];
    self.firmwareLabel.textColor = NSColor.secondaryLabelColor;

    self.eqPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.eqPopup addItemsWithTitles:@[@"Off", @"Bright", @"Excited", @"Mellow", @"Relaxed", @"Vocal", @"Treble boost", @"Bass boost", @"Speech", @"Manual"]];
    [self.eqPopup setTarget:self];
    [self.eqPopup setAction:@selector(eqPresetChanged:)];

    self.touchSensorCheckbox = [[NSButton alloc] init];
    [self.touchSensorCheckbox setButtonType:NSButtonTypeSwitch];
    [self.touchSensorCheckbox setTitle:@"Touch sensor panel"];
    [self.touchSensorCheckbox setTarget:self];
    [self.touchSensorCheckbox setAction:@selector(touchSensorChanged:)];

    self.voiceGuidanceCheckbox = [[NSButton alloc] init];
    [self.voiceGuidanceCheckbox setButtonType:NSButtonTypeSwitch];
    [self.voiceGuidanceCheckbox setTitle:@"Voice guidance"];
    [self.voiceGuidanceCheckbox setTarget:self];
    [self.voiceGuidanceCheckbox setAction:@selector(voiceGuidanceChanged:)];

    self.refreshButton = [[NSButton alloc] init];
    [self.refreshButton setTitle:@"Refresh"];
    [self.refreshButton setBezelStyle:NSBezelStyleRounded];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshFromDevice:)];

    self.refreshSpinner = [[NSProgressIndicator alloc] init];
    self.refreshSpinner.style = NSProgressIndicatorStyleSpinning;
    self.refreshSpinner.controlSize = NSControlSizeSmall;
    self.refreshSpinner.displayedWhenStopped = NO;

    [self setExtendedControlsEnabled:NO];
}

- (void)setupModernLayout {
    NSArray<NSView*>* storyboardViews = @[
        connectedLabel, connectButton, ANCSlider, ANCValuePrefixLabel, ANCValueLabel,
        ANCEnabled, focusOnVoice, virtualSoundLabel, soundPositionLabel, surroundLabel,
        soundPosition, surround,
    ];
    for (NSView* view in storyboardViews) {
        [view removeFromSuperview];
        OmiibaPrepareForAutoLayout(view);
    }

    for (NSView* subview in [self.view.subviews copy]) {
        [subview removeFromSuperview];
    }

    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.drawsBackground = NO;

    NSStackView* root = OmiibaVerticalStack(14);
    root.distribution = NSStackViewDistributionFill;

    NSTextField* appTitle = [NSTextField labelWithString:@"Omiiba Connect"];
    appTitle.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    OmiibaConstrainWidth(appTitle, kContentWidth);
    [root addArrangedSubview:appTitle];

    NSTextField* appSubtitle = [NSTextField labelWithString:@"Sony WH-1000XM3 / XM4 / XM5 / XM6"];
    appSubtitle.font = [NSFont systemFontOfSize:12];
    appSubtitle.textColor = NSColor.secondaryLabelColor;
    OmiibaConstrainWidth(appSubtitle, kContentWidth);
    [root addArrangedSubview:appSubtitle];

    self.modelLabel = [NSTextField labelWithString:@"Model: not connected"];
    self.modelLabel.font = [NSFont systemFontOfSize:11];
    self.modelLabel.textColor = NSColor.tertiaryLabelColor;
    OmiibaConstrainWidth(self.modelLabel, kContentWidth);
    [root addArrangedSubview:self.modelLabel];

    self.connectionIndicator = [[NSView alloc] initWithFrame:NSZeroRect];
    self.connectionIndicator.wantsLayer = YES;
    self.connectionIndicator.layer.cornerRadius = 5;
    self.connectionIndicator.layer.backgroundColor = NSColor.tertiaryLabelColor.CGColor;
    OmiibaPrepareForAutoLayout(self.connectionIndicator);
    [self.connectionIndicator.widthAnchor constraintEqualToConstant:10].active = YES;
    [self.connectionIndicator.heightAnchor constraintEqualToConstant:10].active = YES;

    [connectedLabel setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
    NSStackView* statusRow = OmiibaHorizontalStack(8);
    [statusRow addArrangedSubview:self.connectionIndicator];
    [statusRow addArrangedSubview:connectedLabel];
    OmiibaConstrainWidth(statusRow, kContentWidth);
    [root addArrangedSubview:statusRow];

    [connectButton setBezelStyle:NSBezelStyleRounded];
    [connectButton setControlSize:NSControlSizeLarge];
    [connectButton setTitle:@"Connect headphones"];
    OmiibaConstrainWidth(connectButton, kContentWidth);
    [root addArrangedSubview:connectButton];

    NSTextField* disclaimer = [NSTextField labelWithString:@"Unofficial app — not affiliated with Sony. Use at your own risk."];
    disclaimer.font = [NSFont systemFontOfSize:10];
    disclaimer.textColor = NSColor.tertiaryLabelColor;
    disclaimer.maximumNumberOfLines = 3;
    disclaimer.lineBreakMode = NSLineBreakByWordWrapping;
    disclaimer.cell.wraps = YES;
    OmiibaConstrainWidth(disclaimer, kContentWidth);
    [root addArrangedSubview:disclaimer];

    NSStackView* noiseStack = OmiibaVerticalStack(10);
    [noiseStack addArrangedSubview:ANCEnabled];
    NSStackView* sliderRow = OmiibaHorizontalStack(8);
    [ANCValuePrefixLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                                         forOrientation:NSLayoutConstraintOrientationHorizontal];
    [ANCValueLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                                   forOrientation:NSLayoutConstraintOrientationHorizontal];
    [ANCSlider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [sliderRow addArrangedSubview:ANCValuePrefixLabel];
    [sliderRow addArrangedSubview:ANCSlider];
    [sliderRow addArrangedSubview:ANCValueLabel];
    OmiibaConstrainWidth(sliderRow, kContentWidth);
    [noiseStack addArrangedSubview:sliderRow];
    [noiseStack addArrangedSubview:focusOnVoice];
    OmiibaAddSection(root, @"NOISE CONTROL", noiseStack, kContentWidth);

    NSStackView* virtualStack = OmiibaVerticalStack(8);
    [virtualSoundLabel setMaximumNumberOfLines:2];
    virtualSoundLabel.cell.wraps = YES;
    OmiibaPrepareForAutoLayout(virtualSoundLabel);
    [virtualStack addArrangedSubview:virtualSoundLabel];
    NSStackView* virtualRow = OmiibaHorizontalStack(16);
    NSStackView* surroundCol = OmiibaVerticalStack(4);
    [surroundCol addArrangedSubview:surroundLabel];
    [surroundCol addArrangedSubview:surround];
    NSStackView* positionCol = OmiibaVerticalStack(4);
    [positionCol addArrangedSubview:soundPositionLabel];
    [positionCol addArrangedSubview:soundPosition];
    [virtualRow addArrangedSubview:surroundCol];
    [virtualRow addArrangedSubview:positionCol];
    OmiibaConstrainWidth(virtualRow, kContentWidth);
    [virtualStack addArrangedSubview:virtualRow];
    OmiibaAddSection(root, @"VIRTUAL SOUND", virtualStack, kContentWidth);

    NSStackView* deviceStack = OmiibaVerticalStack(10);
    NSStackView* batteryRow = OmiibaHorizontalStack(10);
    OmiibaPrepareForAutoLayout(self.batteryIndicator);
    OmiibaPrepareForAutoLayout(self.batteryLabel);
    [batteryRow addArrangedSubview:self.batteryIndicator];
    [batteryRow addArrangedSubview:self.batteryLabel];
    [self.batteryIndicator setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.batteryIndicator.widthAnchor constraintGreaterThanOrEqualToConstant:180].active = YES;
    OmiibaConstrainWidth(batteryRow, kContentWidth);
    [deviceStack addArrangedSubview:batteryRow];
    [deviceStack addArrangedSubview:self.codecLabel];
    [deviceStack addArrangedSubview:self.firmwareLabel];

    NSTextField* eqLabel = [NSTextField labelWithString:@"Equalizer"];
    eqLabel.font = [NSFont systemFontOfSize:12];
    OmiibaPrepareForAutoLayout(eqLabel);
    [deviceStack addArrangedSubview:eqLabel];
    OmiibaPrepareForAutoLayout(self.eqPopup);
    [deviceStack addArrangedSubview:self.eqPopup];
    OmiibaPrepareForAutoLayout(self.touchSensorCheckbox);
    OmiibaPrepareForAutoLayout(self.voiceGuidanceCheckbox);
    [deviceStack addArrangedSubview:self.touchSensorCheckbox];
    [deviceStack addArrangedSubview:self.voiceGuidanceCheckbox];

    NSStackView* refreshRow = OmiibaHorizontalStack(8);
    OmiibaPrepareForAutoLayout(self.refreshButton);
    OmiibaPrepareForAutoLayout(self.refreshSpinner);
    [refreshRow addArrangedSubview:self.refreshButton];
    [refreshRow addArrangedSubview:self.refreshSpinner];
    OmiibaConstrainWidth(refreshRow, kContentWidth);
    [deviceStack addArrangedSubview:refreshRow];
    OmiibaAddSection(root, @"DEVICE", deviceStack, kContentWidth);

    OmiibaConstrainWidth(root, kContentWidth);

    NSView* document = [[NSView alloc] init];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    [document addSubview:root];

    const CGFloat padH = 24;
    const CGFloat padV = 20;
    [NSLayoutConstraint activateConstraints:@[
        [root.topAnchor constraintEqualToAnchor:document.topAnchor constant:padV],
        [root.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:padH],
        [root.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-padH],
        [root.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-padV],
    ]];

    self.scrollView.documentView = document;
    [self.view addSubview:self.scrollView];

    NSClipView* clipView = self.scrollView.contentView;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [document.leadingAnchor constraintEqualToAnchor:clipView.leadingAnchor],
        [document.topAnchor constraintEqualToAnchor:clipView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:clipView.widthAnchor],
    ]];

    [self setConnectionIndicatorConnected:NO];
    [self applyCapabilitiesToUI];
}

- (void)applyCapabilitiesToUI {
    if (headphones == nullptr) {
        [self.modelLabel setStringValue:@"Model: not connected"];
        [ANCSlider setMaxValue:19];
        [ANCSlider setNumberOfTickMarks:20];
        [self.eqPopup setHidden:NO];
        [self.touchSensorCheckbox setHidden:NO];
        [self.voiceGuidanceCheckbox setHidden:NO];
        [virtualSoundLabel setHidden:NO];
        [surround setHidden:NO];
        [soundPosition setHidden:NO];
        [surroundLabel setHidden:NO];
        [soundPositionLabel setHidden:NO];
        return;
    }

    const auto& caps = headphones->getCapabilities();
    const auto& status = headphones->getDeviceStatus();
    NSString* modelLine = [NSString stringWithFormat:@"Model: %s  ·  Protocol: %s",
        status.modelName.c_str(),
        status.protocolLabel.c_str()];
    [self.modelLabel setStringValue:modelLine];

    const int maxLevel = caps.asmMaxLevel;
    [ANCSlider setMaxValue:maxLevel];
    [ANCSlider setNumberOfTickMarks:maxLevel + 1];
    if ([ANCSlider intValue] > maxLevel) {
        [ANCSlider setIntValue:maxLevel];
    }

    [self.eqPopup setHidden:!caps.supportsEqualizer];
    [self.touchSensorCheckbox setHidden:!caps.supportsTouchSensor];
    [self.voiceGuidanceCheckbox setHidden:!caps.supportsVoiceGuidance];

    const BOOL virtualVisible = caps.supportsVirtualSound;
    [virtualSoundLabel setHidden:!virtualVisible];
    [surround setHidden:!virtualVisible];
    [soundPosition setHidden:!virtualVisible];
    [surroundLabel setHidden:!virtualVisible];
    [soundPositionLabel setHidden:!virtualVisible];
}

- (void)setConnectionIndicatorConnected:(BOOL)connected {
    if (connected) {
        self.connectionIndicator.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
    } else {
        self.connectionIndicator.layer.backgroundColor = NSColor.tertiaryLabelColor.CGColor;
    }
}

- (void)enableInteractiveControlsIfConnected {
    if (headphones == nullptr || !bt.isConnected() || _refreshInProgressFlag) {
        return;
    }

    const auto& caps = headphones->getCapabilities();

    [ANCEnabled setEnabled:YES];
    [virtualSoundLabel setTextColor:NSColor.labelColor];
    [surroundLabel setTextColor:NSColor.labelColor];
    [soundPositionLabel setTextColor:NSColor.labelColor];

    if (caps.supportsVirtualSound) {
        [surround setEnabled:YES];
        [soundPosition setEnabled:YES];
    }

    if (caps.supportsEqualizer) {
        [self.eqPopup setEnabled:YES];
    }

    [self.touchSensorCheckbox setEnabled:caps.supportsTouchSensor];
    [self.voiceGuidanceCheckbox setEnabled:caps.supportsVoiceGuidance];

    const BOOL ambientOn = [ANCEnabled state] == NSControlStateValueOn;
    if (ambientOn) {
        [ANCSlider setEnabled:YES];
        [ANCValuePrefixLabel setTextColor:NSColor.labelColor];
        [ANCValueLabel setTextColor:NSColor.labelColor];
    } else {
        [ANCSlider setEnabled:NO];
        [ANCValuePrefixLabel setTextColor:NSColor.tertiaryLabelColor];
        [ANCValueLabel setTextColor:NSColor.tertiaryLabelColor];
        [focusOnVoice setEnabled:NO];
    }
}

- (void)setRefreshInProgress:(BOOL)inProgress {
    _refreshInProgressFlag = inProgress;
    if (inProgress) {
        [self.refreshSpinner startAnimation:nil];
        [self.refreshButton setEnabled:NO];
        [ANCSlider setEnabled:NO];
        [ANCEnabled setEnabled:NO];
        [focusOnVoice setEnabled:NO];
        [surround setEnabled:NO];
        [soundPosition setEnabled:NO];
        [self.eqPopup setEnabled:NO];
    } else {
        [self.refreshSpinner stopAnimation:nil];
        [self.refreshButton setEnabled:bt.isConnected()];
        if (headphones != nullptr && bt.isConnected()) {
            [self enableInteractiveControlsIfConnected];
            [self updateGUI];
        }
    }
}

- (void)setExtendedControlsEnabled:(BOOL)enabled {
    [self.batteryLabel setEnabled:enabled];
    [self.batteryIndicator setEnabled:enabled];
    [self.codecLabel setEnabled:enabled];
    [self.firmwareLabel setEnabled:enabled];
    [self.eqPopup setEnabled:enabled];
    [self.touchSensorCheckbox setEnabled:enabled];
    [self.voiceGuidanceCheckbox setEnabled:enabled];
    [self.refreshButton setEnabled:enabled];
}

- (EQ_PRESET)eqPresetForPopupIndex:(NSInteger)index {
    switch (index) {
        case 0: return EQ_PRESET::OFF;
        case 1: return EQ_PRESET::BRIGHT;
        case 2: return EQ_PRESET::EXCITED;
        case 3: return EQ_PRESET::MELLOW;
        case 4: return EQ_PRESET::RELAXED;
        case 5: return EQ_PRESET::VOCAL;
        case 6: return EQ_PRESET::TREBLE_BOOST;
        case 7: return EQ_PRESET::BASS_BOOST;
        case 8: return EQ_PRESET::SPEECH;
        default: return EQ_PRESET::MANUAL;
    }
}

- (NSInteger)popupIndexForEqPreset:(EQ_PRESET)preset {
    switch (preset) {
        case EQ_PRESET::OFF: return 0;
        case EQ_PRESET::BRIGHT: return 1;
        case EQ_PRESET::EXCITED: return 2;
        case EQ_PRESET::MELLOW: return 3;
        case EQ_PRESET::RELAXED: return 4;
        case EQ_PRESET::VOCAL: return 5;
        case EQ_PRESET::TREBLE_BOOST: return 6;
        case EQ_PRESET::BASS_BOOST: return 7;
        case EQ_PRESET::SPEECH: return 8;
        default: return 9;
    }
}

- (void)displayError:(RecoverableException)exc {
    NSString *errorText;
    if (exc.shouldDisconnect) {
        errorText = @"Unexpected error occurred and disconnected.";
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            bt.disconnect();
            dispatch_async(dispatch_get_main_queue(), ^{
                [self displayDisconnectedWithText:errorText];
            });
        });
    } else {
        errorText = @"Unexpected error occurred.";
        [connectedLabel setStringValue:errorText];
    }
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:errorText];
    [alert setInformativeText:@(exc.what())];
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];
}

- (void)displayDisconnectedWithText: (NSString *)text{
    [ANCSlider setEnabled:FALSE];
    [ANCSlider setIntValue:0];
    [focusOnVoice setEnabled:FALSE];
    [ANCEnabled setEnabled:FALSE];
    [ANCEnabled setState:FALSE];
    [focusOnVoice setEnabled:FALSE];
    [surround setEnabled:FALSE];
    [soundPosition setEnabled:FALSE];
    [virtualSoundLabel setTextColor:NSColor.tertiaryLabelColor];
    [surroundLabel setTextColor:NSColor.tertiaryLabelColor];
    [soundPositionLabel setTextColor:NSColor.tertiaryLabelColor];
    [ANCValuePrefixLabel setTextColor:NSColor.tertiaryLabelColor];
    [ANCValueLabel setTextColor:NSColor.tertiaryLabelColor];
    [connectedLabel setStringValue:text];
    [surround selectItemAtIndex:0];
    [soundPosition selectItemAtIndex:0];
    [connectButton setTitle:@"Connect headphones"];
    statusItem.button.image = [NSImage imageNamed:@"NSRefreshTemplate"];
    [self setConnectionIndicatorConnected:NO];
    [self setExtendedControlsEnabled:NO];
    [self setRefreshInProgress:NO];
    [self.batteryLabel setStringValue:@"—"];
    [self.batteryIndicator setDoubleValue:0];
    [self.codecLabel setStringValue:@"Codec: —"];
    [self.firmwareLabel setStringValue:@"Firmware: —"];
    [self applyCapabilitiesToUI];
}

- (void)statusItemClick:(id)sender {
    headphones->setAmbientSoundControl(TRUE);
    if ([focusOnVoice isEnabled]) {
        [ANCSlider setIntValue:0];
        headphones->setAsmLevel(0);
        [focusOnVoice setEnabled:FALSE];
    } else {
        const int maxLevel = headphones->getCapabilities().asmMaxLevel;
        [ANCSlider setIntValue:maxLevel];
        headphones->setAsmLevel(maxLevel);
        [focusOnVoice setEnabled:TRUE];
    }

    [self updateHeadphones];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (IBAction)connectToDevice:(id)sender {
    statusItem.button.image = [NSImage imageNamed:@"NSRefreshTemplate"];

    if (bt.isConnected()) {
        _refreshGeneration++;
        bt.disconnect();
        delete headphones;
        headphones = nullptr;
        [self displayDisconnectedWithText:@"Not connected"];
        return;
    }

    IOBluetoothDeviceSelectorController *dSelector = [IOBluetoothDeviceSelectorController deviceSelector];
    int result = [dSelector runModal];

    if (result == kIOBluetoothUISuccess) {
        IOBluetoothDevice *device = [[dSelector getResults] lastObject];
        try {
            bt.connect([[device addressString] UTF8String]);
        } catch (RecoverableException& exc) {
            [connectedLabel setStringValue:@"Connection failed"];
            [self displayError:exc];
            return;
        } catch (const std::exception& exc) {
            RecoverableException recoverable(exc.what(), false);
            [connectedLabel setStringValue:@"Connection failed"];
            [self displayError:recoverable];
            return;
        }

        for (int wait = 0; wait < 80 && !bt.isConnected(); wait++) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }

        if (bt.isConnected()) {
            [connectedLabel setStringValue:[device nameOrAddress]];
            [connectButton setTitle:@"Disconnect"];
            [ANCSlider setEnabled:TRUE];
            [ANCEnabled setEnabled:TRUE];
            [ANCEnabled setState:TRUE];
            [focusOnVoice setEnabled:FALSE];
            [surround setEnabled:TRUE];
            [soundPosition setEnabled:TRUE];
            [virtualSoundLabel setTextColor:NSColor.labelColor];
            [surroundLabel setTextColor:NSColor.labelColor];
            [soundPositionLabel setTextColor:NSColor.labelColor];
            [ANCValuePrefixLabel setTextColor:NSColor.labelColor];
            [ANCValueLabel setTextColor:NSColor.labelColor];
            statusItem.button.image = [NSImage imageNamed:@"NSHomeTemplate"];
            headphones = new Headphones(bt);
            headphones->configureForDevice([[device nameOrAddress] UTF8String]);
            [self setConnectionIndicatorConnected:YES];
            [self setExtendedControlsEnabled:YES];
            [self applyCapabilitiesToUI];
            [self refreshFromDevice:sender];
        } else {
            [self displayDisconnectedWithText:@"Connection timed out"];
            bt.disconnect();
        }
    } else {
        [self displayDisconnectedWithText:@"Not connected"];
    }
}

- (void)finishRefreshGeneration:(NSInteger)generation {
    if (generation != _refreshGeneration) {
        return;
    }
    [self setRefreshInProgress:NO];
}

- (IBAction)refreshFromDevice:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }

    const NSInteger generation = ++_refreshGeneration;
    [self setRefreshInProgress:YES];

    // Failsafe: never leave the spinner running if Bluetooth I/O stalls.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation == _refreshGeneration) {
            [self setRefreshInProgress:NO];
        }
    });

    const BOOL fullRefresh = (sender == self.refreshButton);

    dispatch_async(_bluetoothQueue, ^{
        try {
            if (bt.isConnected() && headphones != nullptr) {
                headphones->refreshFromDevice(fullRefresh);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (generation != _refreshGeneration) {
                    return;
                }
                [self updateGUI];
                [self finishRefreshGeneration:generation];
            });
        } catch (RecoverableException& exc) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (generation != _refreshGeneration) {
                    return;
                }
                [self finishRefreshGeneration:generation];
                [self displayError:exc];
            });
        } catch (const std::exception& exc) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (generation != _refreshGeneration) {
                    return;
                }
                [self finishRefreshGeneration:generation];
                RecoverableException recoverable(exc.what(), false);
                [self displayError:recoverable];
            });
        } catch (...) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (generation != _refreshGeneration) {
                    return;
                }
                [self finishRefreshGeneration:generation];
                [connectedLabel setStringValue:@"Refresh failed"];
            });
        }
    });
}

- (IBAction)ANCSliderChanged:(id)sender {
    if (headphones == nullptr || _refreshInProgressFlag) {
        return;
    }

    headphones->setAmbientSoundControl(TRUE);
    [ANCEnabled setState:NSControlStateValueOn];
    [ANCSlider setEnabled:YES];
    [ANCValuePrefixLabel setTextColor:NSColor.labelColor];
    [ANCValueLabel setTextColor:NSColor.labelColor];
    const int level = ANCSlider.intValue;
    headphones->setAsmLevel(level);
    [ANCValueLabel setIntValue:level];

    const NSInteger debounceGeneration = ++_ancDebounceGeneration;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            if (debounceGeneration != self->_ancDebounceGeneration) {
                return;
            }
            [self updateHeadphones];
        });
}

- (IBAction)ANCEnabledButtonChanged:(id)sender {
    headphones->setAmbientSoundControl(ANCEnabled.state);
    if (ANCEnabled.state == NSControlStateValueOn) {
        [ANCSlider setEnabled:YES];
        [ANCValuePrefixLabel setTextColor:NSColor.labelColor];
        [ANCValueLabel setTextColor:NSColor.labelColor];
    } else {
        [ANCSlider setEnabled:NO];
        [focusOnVoice setEnabled:NO];
    }
    [self updateHeadphones];
}

- (IBAction)focusOnVoiceChanged:(id)sender {
    headphones->setFocusOnVoice(focusOnVoice.state);
    [self updateHeadphones];
}

- (IBAction)surroundChanged:(id)sender {
    headphones->setVptType((int) surround.indexOfSelectedItem);
    headphones->setSurroundPosition(SOUND_POSITION_PRESET_ARRAY[0]);
    [self updateHeadphones];
}

- (IBAction)soundPositionChanged:(id)sender {
    headphones->setVptType(0);
    headphones->setSurroundPosition(SOUND_POSITION_PRESET_ARRAY[soundPosition.indexOfSelectedItem]);
    [self updateHeadphones];
}

- (IBAction)eqPresetChanged:(id)sender {
    if (headphones == nullptr || _refreshInProgressFlag) {
        return;
    }

    headphones->setEqualizerPreset([self eqPresetForPopupIndex:self.eqPopup.indexOfSelectedItem]);

    const NSInteger debounceGeneration = ++_eqDebounceGeneration;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            if (debounceGeneration != self->_eqDebounceGeneration) {
                return;
            }
            [self updateHeadphones];
        });
}

- (IBAction)touchSensorChanged:(id)sender {
    headphones->setTouchSensorEnabled(self.touchSensorCheckbox.state == NSControlStateValueOn);
    [self updateHeadphones];
}

- (IBAction)voiceGuidanceChanged:(id)sender {
    headphones->setVoiceGuidanceEnabled(self.voiceGuidanceCheckbox.state == NSControlStateValueOn);
    [self updateHeadphones];
}

- (void)updateHeadphones {
    if (headphones == nullptr) {
        return;
    }

    dispatch_async(_bluetoothQueue, ^{
        if (!bt.isConnected() || headphones == nullptr) {
            return;
        }

        if (!headphones->isChanged()) {
            return;
        }

        try {
            headphones->setChanges();
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateGUI];
            });
        } catch (RecoverableException& exc) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [connectedLabel setStringValue:@"Setting failed — try again"];
                [self displayError:exc];
            });
        } catch (const std::exception& exc) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RecoverableException recoverable(exc.what(), false);
                [connectedLabel setStringValue:@"Setting failed — try again"];
                [self displayError:recoverable];
            });
        }
    });
}

- (void)updateGUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (headphones == nullptr) {
            return;
        }
        [self->ANCEnabled setState:headphones->getAmbientSoundControl()];
        [self->focusOnVoice setState:headphones->getFocusOnVoice()];
        [self->surround selectItemAtIndex:headphones->getVptType()];
        SOUND_POSITION_PRESET preset = headphones->getSurroundPosition();
        int index = 0;
        for (SOUND_POSITION_PRESET p : SOUND_POSITION_PRESET_ARRAY) {
            if (p == preset) {
                break;
            }
            index++;
        }
        [self->soundPosition selectItemAtIndex:index];

        const int asmDisplayLevel = headphones->getDisplayAsmLevel();
        [self->ANCValueLabel setIntValue:asmDisplayLevel];
        if (!headphones->hasPendingAmbientChanges()) {
            [self->ANCSlider setIntValue:asmDisplayLevel];
        }
        if (headphones->isFocusOnVoiceAvailable()) {
            [self->focusOnVoice setTitle:@"Focus on Voice"];
            [self->focusOnVoice setEnabled:TRUE];
            statusItem.button.image = [NSImage imageNamed:@"NSFlowViewTemplate"];
        }
        else {
            [self->focusOnVoice setTitle:@"Focus on Voice isn't enabled on this level."];
            statusItem.button.image = [NSImage imageNamed:@"NSHomeTemplate"];
            [self->focusOnVoice setEnabled:FALSE];
        }

        const auto& status = headphones->getDeviceStatus();
        if (status.hasBattery) {
            [self.batteryIndicator setDoubleValue:status.batteryPercent];
            [self.batteryLabel setStringValue:[NSString stringWithFormat:@"%d%%", status.batteryPercent]];
            if (status.batteryPercent <= 20) {
                self.batteryIndicator.warningValue = 20;
                self.batteryIndicator.criticalValue = 10;
            }
        } else {
            [self.batteryIndicator setDoubleValue:0];
            [self.batteryLabel setStringValue:@"—"];
        }
        if (status.hasCodec) {
            [self.codecLabel setStringValue:[NSString stringWithFormat:@"Codec: %s", status.audioCodec.c_str()]];
        } else {
            [self.codecLabel setStringValue:@"Codec: —"];
        }
        if (status.hasFirmware) {
            [self.firmwareLabel setStringValue:[NSString stringWithFormat:@"Firmware: %s", status.firmwareVersion.c_str()]];
        } else {
            [self.firmwareLabel setStringValue:@"Firmware: —"];
        }
        if (!status.modelName.empty()) {
            NSString* modelLine = [NSString stringWithFormat:@"Model: %s  ·  Protocol: %s",
                status.modelName.c_str(),
                status.protocolLabel.c_str()];
            [self.modelLabel setStringValue:modelLine];
        }
        if (!headphones->hasPendingEqChanges()) {
            SEL eqAction = self.eqPopup.action;
            [self.eqPopup setAction:nil];
            [self.eqPopup selectItemAtIndex:[self popupIndexForEqPreset:headphones->getDisplayEqPreset()]];
            [self.eqPopup setAction:eqAction];
        }
        [self.touchSensorCheckbox setState:headphones->getTouchSensorEnabled() ? NSControlStateValueOn : NSControlStateValueOff];
        [self.voiceGuidanceCheckbox setState:headphones->getVoiceGuidanceEnabled() ? NSControlStateValueOn : NSControlStateValueOff];
        [self applyCapabilitiesToUI];
        [self enableInteractiveControlsIfConnected];
    });
}

@end
