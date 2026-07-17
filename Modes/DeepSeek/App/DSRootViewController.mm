#import "DSRootViewController.h"

#include "recovered_catalog.hpp"

namespace {

NSString* DSString(const char* value) {
    if (value == nullptr) {
        return @"";
    }
    NSString* string = [NSString stringWithUTF8String:value];
    return string ?: @"";
}

UILabel* DSLabel(
    NSString* text,
    UIFont* font,
    UIColor* color,
    NSInteger lines
) {
    UILabel* label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    return label;
}

}  // namespace

@interface DSFunctionViewController : UIViewController

- (instancetype)initWithFunction:
    (const recovered::RecoveredFunction&)function;

@end

@interface DSFunctionViewController ()

@property(nonatomic, copy) NSString* functionTitle;
@property(nonatomic, copy) NSString* functionSubtitle;
@property(nonatomic, copy) NSString* pseudocode;

@end

@implementation DSFunctionViewController

- (instancetype)initWithFunction:
    (const recovered::RecoveredFunction&)function {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _functionTitle = DSString(function.symbol);
        _functionSubtitle = [NSString stringWithFormat:
            @"%@ · 0x%@ · %@:%zu-%zu",
            DSString(function.module),
            DSString(function.address),
            DSString(function.source_file),
            function.first_line,
            function.last_line
        ];
        _pseudocode = DSString(function.pseudocode);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"Recovered body";

    UILabel* titleLabel = DSLabel(
        self.functionTitle,
        [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightSemibold],
        UIColor.labelColor,
        0
    );
    UILabel* subtitleLabel = DSLabel(
        self.functionSubtitle,
        [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular],
        UIColor.secondaryLabelColor,
        0
    );
    UITextView* textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.editable = NO;
    textView.alwaysBounceVertical = YES;
    textView.font =
        [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    textView.text = self.pseudocode;
    textView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    textView.layer.cornerRadius = 14;
    textView.textContainerInset = UIEdgeInsetsMake(14, 12, 14, 12);

    UIStackView* header = [[UIStackView alloc]
        initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.axis = UILayoutConstraintAxisVertical;
    header.spacing = 6;

    [self.view addSubview:header];
    [self.view addSubview:textView];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14],
        [header.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [textView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14],
        [textView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [textView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [textView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8],
    ]];
}

@end

@interface DSRootViewController ()
    <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property(nonatomic, strong) UISegmentedControl* modeControl;
@property(nonatomic, strong) UIView* contentView;
@property(nonatomic, strong) UITableView* tableView;
@property(nonatomic, strong) UISearchBar* searchBar;
@property(nonatomic, copy) NSArray<NSDictionary<NSString*, NSString*>*>* results;
@property(nonatomic, strong) UITextView* conversationView;
@property(nonatomic, strong) UITextView* promptView;

@end

@implementation DSRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.title = @"DeepSeek";
    self.navigationItem.largeTitleDisplayMode =
        UINavigationItemLargeTitleDisplayModeNever;

    self.modeControl = [[UISegmentedControl alloc]
        initWithItems:@[@"Chat", @"Pseudocode", @"About"]];
    self.modeControl.selectedSegmentIndex = 0;
    [self.modeControl addTarget:self
                         action:@selector(modeChanged:)
               forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.modeControl;

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.contentView];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self showChat];
}

- (void)modeChanged:(UISegmentedControl*)sender {
    switch (sender.selectedSegmentIndex) {
        case 1:
            [self showPseudocode];
            break;
        case 2:
            [self showAbout];
            break;
        default:
            [self showChat];
            break;
    }
}

- (void)clearContent {
    [self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (void)showChat {
    [self clearContent];

    UILabel* eyebrow = DSLabel(
        @"BUILDABLE RECOVERY",
        [UIFont systemFontOfSize:12 weight:UIFontWeightBold],
        UIColor.systemBlueColor,
        1
    );
    UILabel* title = DSLabel(
        @"How can I help you today?",
        [UIFont systemFontOfSize:28 weight:UIFontWeightBold],
        UIColor.labelColor,
        0
    );
    UILabel* note = DSLabel(
        @"This reconstructed shell is intentionally offline. It preserves the "
        @"recovered UI shape, resources, symbols, and all Ghidra bodies without "
        @"pretending the removed model/network implementation was recovered.",
        [UIFont systemFontOfSize:14 weight:UIFontWeightRegular],
        UIColor.secondaryLabelColor,
        0
    );

    self.conversationView = [[UITextView alloc] init];
    self.conversationView.translatesAutoresizingMaskIntoConstraints = NO;
    self.conversationView.editable = NO;
    self.conversationView.font =
        [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.conversationView.text =
        @"Recovered shell ready.\n\nOpen Pseudocode to search all 6,006 "
        @"decompiled functions by module, address, or symbol.";
    self.conversationView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.conversationView.layer.cornerRadius = 16;
    self.conversationView.textContainerInset = UIEdgeInsetsMake(16, 14, 16, 14);

    self.promptView = [[UITextView alloc] init];
    self.promptView.translatesAutoresizingMaskIntoConstraints = NO;
    self.promptView.font = [UIFont systemFontOfSize:16];
    self.promptView.text = @"Ask about the recovered code…";
    self.promptView.textColor = UIColor.secondaryLabelColor;
    self.promptView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.promptView.layer.cornerRadius = 16;
    self.promptView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);

    UIButton* send = [UIButton buttonWithType:UIButtonTypeSystem];
    send.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration* sendConfiguration =
        [UIButtonConfiguration filledButtonConfiguration];
    sendConfiguration.title = @"Send";
    sendConfiguration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    send.configuration = sendConfiguration;
    [send addTarget:self
             action:@selector(sendTapped:)
   forControlEvents:UIControlEventTouchUpInside];

    UIStackView* header = [[UIStackView alloc]
        initWithArrangedSubviews:@[eyebrow, title, note]];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.axis = UILayoutConstraintAxisVertical;
    header.spacing = 8;

    [self.contentView addSubview:header];
    [self.contentView addSubview:self.conversationView];
    [self.contentView addSubview:self.promptView];
    [self.contentView addSubview:send];
    UILayoutGuide* safe = self.contentView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18],
        [header.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [header.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.conversationView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:18],
        [self.conversationView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.conversationView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.promptView.topAnchor constraintEqualToAnchor:self.conversationView.bottomAnchor constant:12],
        [self.promptView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.promptView.heightAnchor constraintEqualToConstant:54],
        [send.leadingAnchor constraintEqualToAnchor:self.promptView.trailingAnchor constant:10],
        [send.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [send.centerYAnchor constraintEqualToAnchor:self.promptView.centerYAnchor],
        [send.widthAnchor constraintEqualToConstant:76],
        [self.promptView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
    ]];
}

- (void)sendTapped:(UIButton*)sender {
    (void)sender;
    NSString* prompt = [
        self.promptView.text
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet
    ];
    if (prompt.length == 0 || [prompt hasPrefix:@"Ask about"]) {
        return;
    }
    self.conversationView.text = [self.conversationView.text
        stringByAppendingFormat:
            @"\n\nYou\n%@\n\nRecovered shell\n"
             "Network inference is not present in the IPA reconstruction. "
             "Use the Pseudocode tab to inspect the recovered implementation.",
            prompt
    ];
    self.promptView.text = @"";
    self.promptView.textColor = UIColor.labelColor;
}

- (void)showPseudocode {
    [self clearContent];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search symbol, module, or address";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;

    self.tableView = [[UITableView alloc]
        initWithFrame:CGRectZero
                style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 70;

    [self.contentView addSubview:self.searchBar];
    [self.contentView addSubview:self.tableView];
    UILayoutGuide* safe = self.contentView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:safe.topAnchor constant:4],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-8],
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
    ]];
    [self reloadResults:@""];
}

- (void)reloadResults:(NSString*)query {
    const char* utf8 = query.UTF8String ?: "";
    const auto matches = recovered::search(utf8, 250);
    NSMutableArray* rows = [NSMutableArray arrayWithCapacity:matches.size()];
    for (const recovered::RecoveredFunction* function : matches) {
        [rows addObject:@{
            @"module": DSString(function->module),
            @"address": DSString(function->address),
            @"symbol": DSString(function->symbol),
        }];
    }
    self.results = rows;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView*)tableView
    numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.results.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView
       cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    static NSString* const identifier = @"RecoveredFunction";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:identifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.font =
            [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
        cell.detailTextLabel.font =
            [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    }
    NSDictionary* row = self.results[indexPath.row];
    cell.textLabel.text = row[@"symbol"];
    cell.detailTextLabel.text = [NSString stringWithFormat:
        @"%@ · 0x%@",
        row[@"module"],
        row[@"address"]
    ];
    return cell;
}

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary* row = self.results[indexPath.row];
    const recovered::RecoveredFunction* function = recovered::find(
        [row[@"module"] UTF8String],
        [row[@"address"] UTF8String]
    );
    if (function == nullptr) {
        return;
    }
    DSFunctionViewController* detail =
        [[DSFunctionViewController alloc] initWithFunction:*function];
    [self.navigationController pushViewController:detail animated:YES];
}

- (void)searchBar:(UISearchBar*)searchBar
    textDidChange:(NSString*)searchText {
    (void)searchBar;
    [self reloadResults:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar*)searchBar {
    [searchBar resignFirstResponder];
}

- (void)showAbout {
    [self clearContent];

    const auto modules = recovered::module_summaries();
    NSMutableString* moduleText = [NSMutableString string];
    for (const auto& module : modules) {
        [moduleText appendFormat:
            @"%@  %zu\n",
            DSString(module.module.c_str()),
            module.function_count
        ];
    }

    UILabel* title = DSLabel(
        @"Recovered, then made buildable",
        [UIFont systemFontOfSize:28 weight:UIFontWeightBold],
        UIColor.labelColor,
        0
    );
    UILabel* explanation = DSLabel(
        [NSString stringWithFormat:
            @"This target compiles every one of the %zu recovered Ghidra "
             "function bodies into a searchable catalog. Original export files "
             "and recoverable bundle resources are copied into the app bundle.\n\n"
             "The catalog is faithful evidence, not executable original logic. "
             "Optimized Swift types, runtime state, source-level control, secrets, "
             "and removed code cannot be recreated safely from the binary alone.",
            recovered::function_count()
        ],
        [UIFont systemFontOfSize:16 weight:UIFontWeightRegular],
        UIColor.secondaryLabelColor,
        0
    );
    UILabel* modulesLabel = DSLabel(
        moduleText,
        [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular],
        UIColor.labelColor,
        0
    );
    modulesLabel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    modulesLabel.layer.cornerRadius = 14;
    modulesLabel.layer.masksToBounds = YES;

    UIStackView* stack = [[UIStackView alloc]
        initWithArrangedSubviews:@[title, explanation, modulesLabel]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    [self.contentView addSubview:stack];
    UILayoutGuide* safe = self.contentView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:28],
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:22],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-22],
    ]];
}

@end
