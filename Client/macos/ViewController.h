//
//  ViewController.h
//  Omiiba Connect
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

BluetoothWrapper bt = (BluetoothWrapper)nil;
Headphones* headphones;
NSStatusItem* statusItem;

@interface ViewController : NSViewController
@property (weak, nonatomic) IBOutlet NSTextField *connectedLabel;
@property (weak, nonatomic) IBOutlet NSTextField *ANCValuePrefixLabel;
@property (weak, nonatomic) IBOutlet NSTextField *ANCValueLabel;
@property (weak, nonatomic) IBOutlet NSButton *focusOnVoice;
@property (weak, nonatomic) IBOutlet NSButton *connectButton;
@property (weak, nonatomic) IBOutlet NSSlider *ANCSlider;
@property (weak, nonatomic) IBOutlet NSButton *ANCEnabled;
@property (weak, nonatomic) IBOutlet NSTextField *virtualSoundLabel;
@property (weak, nonatomic) IBOutlet NSTextField *soundPositionLabel;
@property (weak, nonatomic) IBOutlet NSTextField *surroundLabel;
@property (weak, nonatomic) IBOutlet NSPopUpButton *soundPosition;
@property (weak, nonatomic) IBOutlet NSPopUpButton *surround;

@property (strong, nonatomic) NSTextField *batteryLabel;
@property (strong, nonatomic) NSTextField *codecLabel;
@property (strong, nonatomic) NSTextField *firmwareLabel;
@property (strong, nonatomic) NSPopUpButton *eqPopup;
@property (strong, nonatomic) NSButton *touchSensorCheckbox;
@property (strong, nonatomic) NSButton *voiceGuidanceCheckbox;
@property (strong, nonatomic) NSButton *refreshButton;
@property (strong, nonatomic) NSLevelIndicator *batteryIndicator;
@property (strong, nonatomic) NSView *connectionIndicator;
@property (strong, nonatomic) NSProgressIndicator *refreshSpinner;
@property (strong, nonatomic) NSScrollView *scrollView;
@property (strong, nonatomic) NSTextField *modelLabel;
@property (strong, nonatomic) NSStackView *manualEqPanel;
@property (strong, nonatomic) NSSegmentedControl *eqProfileSegment;

- (void)applyCapabilitiesToUI;
@end
