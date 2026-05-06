#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>

#define BACKEND_URL @"https://op724ox0393.vicp.fun/api.php"
// 改用App沙盒路径（重签名注入唯一有权限的路径）
#define TOKEN_PATH [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"cardkey_token.txt"]

static BOOL isVerified = NO;
static BOOL hasShownAlert = NO;
static NSString *authToken = nil;

@interface CardKeyViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UIView *alertView;
@property (nonatomic, strong) UITextField *cardKeyField;
@property (nonatomic, strong) UIButton *submitBtn;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation CardKeyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self setupUI];
}

- (NSString *)getDeviceId {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    NSString *rawStr = [NSString stringWithFormat:@"%@_%@", deviceModel, systemVersion];
    NSData *rawData = [rawStr dataUsingEncoding:NSUTF8StringEncoding];
    // 修复1：改用兼容旧SDK的base64方法
    return [rawData base64EncodedStringWithOptions:0];
}

- (void)setupUI {
    self.overlayView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    
    CGFloat w = 300, h = 300;
    self.alertView = [[UIView alloc] initWithFrame:CGRectMake((UIScreen.mainScreen.bounds.size.width-w)/2, (UIScreen.mainScreen.bounds.size.height-h)/2, w, h)];
    self.alertView.backgroundColor = UIColor.whiteColor;
    self.alertView.layer.cornerRadius = 12;
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 30, w, 30)];
    self.titleLabel.text = @"卡密验证";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    
    self.cardKeyField = [[UITextField alloc] initWithFrame:CGRectMake(30, 80, w-60, 45)];
    self.cardKeyField.borderStyle = UITextBorderStyleRoundedRect;
    self.cardKeyField.placeholder = @"请输入卡密";
    self.cardKeyField.textAlignment = NSTextAlignmentCenter;
    
    self.submitBtn = [[UIButton alloc] initWithFrame:CGRectMake(30, 140, w-60, 45)];
    [self.submitBtn setTitle:@"验证" forState:UIControlStateNormal];
    [self.submitBtn setBackgroundColor:UIColor.systemBlueColor];
    [self.submitBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.submitBtn addTarget:self action:@selector(submitCardKey) forControlEvents:UIControlEventTouchUpInside];
    self.submitBtn.layer.cornerRadius = 8;
    
    // 修复2：初始化时指定spinner样式（兼容旧SDK）
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.frame = CGRectMake(w/2-20, 200, 40, 40);
    
    [self.alertView addSubview:self.titleLabel];
    [self.alertView addSubview:self.cardKeyField];
    [self.alertView addSubview:self.submitBtn];
    [self.alertView addSubview:self.spinner];
    [self.overlayView addSubview:self.alertView];
    [self.view addSubview:self.overlayView];
    
    // 启动检查沙盒Token
    [self checkLocalToken];
}

- (void)checkLocalToken {
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:TOKEN_PATH]) {
        NSString *token = [NSString stringWithContentsOfFile:TOKEN_PATH encoding:NSUTF8StringEncoding error:nil];
        if (token.length > 0) {
            isVerified = YES;
            hasShownAlert = YES;
            [self dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
}

- (void)submitCardKey {
    if (self.cardKeyField.text.length == 0) {
        [self showMsg:@"请输入卡密"];
        return;
    }
    [self.spinner startAnimating];
    self.submitBtn.enabled = NO;
    
    NSString *deviceId = self.getDeviceId;
    NSString *url = [NSString stringWithFormat:@"%@?action=verify&cardKey=%@&deviceId=%@", 
                     BACKEND_URL, 
                     [self.cardKeyField.text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], 
                     [deviceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.submitBtn.enabled = YES;
            
            if (error || !data) {
                [self showMsg:@"网络错误"];
                return;
            }
            
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json[@"success"] boolValue]) {
                // Token写入App沙盒（永久保存）
                [json[@"token"] writeToFile:TOKEN_PATH atomically:YES encoding:NSUTF8StringEncoding error:nil];
                isVerified = YES;
                hasShownAlert = YES;
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                [self showMsg:json[@"message"] ?: @"验证失败"];
            }
        });
    }];
    [task resume];
}

- (void)showMsg:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

static void showAlert() {
    if (hasShownAlert || isVerified) return;
    hasShownAlert = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (root) {
            CardKeyViewController *vc = [[CardKeyViewController alloc] init];
            vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
            [root presentViewController:vc animated:NO completion:nil];
        }
    });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass(self.class);
    if (![cls hasPrefix:@"CardKey"] && !hasShownAlert && !isVerified) {
        showAlert();
    }
}
%end

%ctor {
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:TOKEN_PATH]) {
        NSString *t = [NSString stringWithContentsOfFile:TOKEN_PATH encoding:NSUTF8StringEncoding error:nil];
        if (t.length > 0) {
            isVerified = YES;
            hasShownAlert = YES;
            return;
        }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        showAlert();
    });
}
