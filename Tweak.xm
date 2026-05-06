#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>

#define BACKEND_URL @"https://op724ox0393.vicp.fun/api.php"
#define TOKEN_PATH @"/var/mobile/Library/Preferences/com.plugin.cardkey.token"
#define TOKEN_PERMS 0600
#define IS_VERIFIED_KEY @"com.plugin.cardkey.isVerified"
#define HAS_SHOWN_ALERT_KEY @"com.plugin.cardkey.hasShownAlert"

static BOOL isVerified = NO;
static BOOL hasShownAlert = NO;
static NSString *authToken = nil;
static NSString *adContent = nil;
static NSString *adImageUrl = nil;
static NSString *linkText = nil;
static NSString *linkUrl = nil;

@interface CardKeyViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UIView *alertView;
@property (nonatomic, strong) UITextField *cardKeyField;
@property (nonatomic, strong) UIButton *submitBtn;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *adLabel;
@property (nonatomic, strong) UIImageView *adImageView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton *linkBtn;
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
    NSString *deviceName = [[UIDevice currentDevice] name];
    NSString *rawString = [NSString stringWithFormat:@"%@_%@_%@", deviceModel, systemVersion, deviceName];
    return [[rawString dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}

- (void)setupUI {
    self.overlayView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.overlayView.userInteractionEnabled = YES;
    
    CGFloat alertWidth = 300;
    CGFloat alertHeight = 420;
    CGFloat alertX = ([UIScreen mainScreen].bounds.size.width - alertWidth) / 2;
    CGFloat alertY = ([UIScreen mainScreen].bounds.size.height - alertHeight) / 2;
    
    self.alertView = [[UIView alloc] initWithFrame:CGRectMake(alertX, alertY, alertWidth, alertHeight)];
    self.alertView.backgroundColor = [UIColor whiteColor];
    self.alertView.layer.cornerRadius = 12;
    self.alertView.layer.masksToBounds = YES;
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, alertWidth - 40, 40)];
    self.titleLabel.text = @"卡密验证";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.titleLabel.textColor = [UIColor blackColor];
    
    self.cardKeyField = [[UITextField alloc] initWithFrame:CGRectMake(30, 80, alertWidth - 60, 45)];
    self.cardKeyField.borderStyle = UITextBorderStyleRoundedRect;
    self.cardKeyField.placeholder = @"请输入卡密";
    self.cardKeyField.textAlignment = NSTextAlignmentCenter;
    self.cardKeyField.font = [UIFont systemFontOfSize:16];
    self.cardKeyField.delegate = self;
    self.cardKeyField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    self.submitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitBtn.frame = CGRectMake(30, 140, alertWidth - 60, 45);
    [self.submitBtn setTitle:@"验证" forState:UIControlStateNormal];
    self.submitBtn.backgroundColor = [UIColor systemBlueColor];
    [self.submitBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.submitBtn.layer.cornerRadius = 8;
    [self.submitBtn addTarget:self action:@selector(submitCardKey) forControlEvents:UIControlEventTouchUpInside];
    
    self.linkBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.linkBtn.frame = CGRectMake(20, 195, alertWidth - 40, 25);
    [self.linkBtn setTitle:@"加载中..." forState:UIControlStateNormal];
    self.linkBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    self.linkBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.linkBtn.titleLabel.numberOfLines = 0;
    [self.linkBtn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [self.linkBtn addTarget:self action:@selector(openLink) forControlEvents:UIControlEventTouchUpInside];
    self.linkBtn.hidden = YES;
    
    self.adLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 230, alertWidth - 40, 30)];
    self.adLabel.text = @"广告";
    self.adLabel.textAlignment = NSTextAlignmentCenter;
    self.adLabel.font = [UIFont boldSystemFontOfSize:14];
    self.adLabel.textColor = [UIColor grayColor];
    
    self.adImageView = [[UIImageView alloc] initWithFrame:CGRectMake(30, 270, alertWidth - 60, 120)];
    self.adImageView.backgroundColor = [UIColor lightGrayColor];
    self.adImageView.contentMode = UIViewContentModeScaleToFill;
    self.adImageView.layer.cornerRadius = 8;
    self.adImageView.layer.masksToBounds = YES;
    
    self.spinner = [[UIActivityIndicatorView alloc] init];
    self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleMedium;
    self.spinner.frame = CGRectMake((alertWidth - 40) / 2, 350, 40, 40);
    self.spinner.hidden = YES;
    
    [self.alertView addSubview:self.titleLabel];
    [self.alertView addSubview:self.cardKeyField];
    [self.alertView addSubview:self.submitBtn];
    [self.alertView addSubview:self.linkBtn];
    [self.alertView addSubview:self.adLabel];
    [self.alertView addSubview:self.adImageView];
    [self.alertView addSubview:self.spinner];
    [self.overlayView addSubview:self.alertView];
    [self.view addSubview:self.overlayView];
    
    [self loadAdContent];
    [self checkExistingToken];
}

- (void)loadAdContent {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *urlString = [NSString stringWithFormat:@"%@?action=getAd", BACKEND_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
        request.HTTPMethod = @"GET";
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [self.linkBtn setTitle:@"点击获取更多信息" forState:UIControlStateNormal];
                    self.linkBtn.hidden = NO;
                    return;
                }
                
                if (data) {
                    NSError *jsonError;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                    if (!jsonError && [json[@"success"] boolValue]) {
                        adContent = json[@"adContent"];
                        adImageUrl = json[@"adImageUrl"];
                        linkText = json[@"linkText"];
                        linkUrl = json[@"linkUrl"];
                        
                        self.adLabel.text = adContent ?: @"广告";
                        
                        if (linkText && linkText.length > 0 && linkUrl && linkUrl.length > 0) {
                            [self.linkBtn setTitle:linkText forState:UIControlStateNormal];
                            self.linkBtn.hidden = NO;
                        } else {
                            [self.linkBtn setTitle:@"点击获取更多信息" forState:UIControlStateNormal];
                            self.linkBtn.hidden = NO;
                        }
                        
                        if (adImageUrl && adImageUrl.length > 0) {
                            [self loadAdImage];
                        }
                    } else {
                        [self.linkBtn setTitle:@"点击获取更多信息" forState:UIControlStateNormal];
                        self.linkBtn.hidden = NO;
                    }
                } else {
                    [self.linkBtn setTitle:@"点击获取更多信息" forState:UIControlStateNormal];
                    self.linkBtn.hidden = NO;
                }
            });
        }];
        [task resume];
    });
}

- (void)openLink {
    if (linkUrl && linkUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:linkUrl];
        if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

- (void)loadAdImage {
    if (adImageUrl) {
        NSURL *url = [NSURL URLWithString:adImageUrl];
        NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (data && !error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIImage *image = [UIImage imageWithData:data];
                    if (image) {
                        self.adImageView.image = image;
                    }
                });
            }
        }];
        [task resume];
    }
}

- (void)checkExistingToken {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:TOKEN_PATH]) {
        NSString *savedToken = [NSString stringWithContentsOfFile:TOKEN_PATH encoding:NSUTF8StringEncoding error:nil];
        if (savedToken && savedToken.length > 0) {
            authToken = savedToken;
            NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.plugin.cardkey"];
            BOOL savedIsVerified = [defaults boolForKey:IS_VERIFIED_KEY];
            BOOL savedHasShownAlert = [defaults boolForKey:HAS_SHOWN_ALERT_KEY];
            
            if (savedIsVerified) {
                isVerified = YES;
                hasShownAlert = savedHasShownAlert;
                [self dismissAlert];
                [self verifyToken:savedToken];
            } else {
                [self verifyToken:savedToken];
            }
        }
    }
}

- (void)submitCardKey {
    NSString *cardKey = self.cardKeyField.text;
    if (cardKey.length == 0) {
        [self showAlert:@"请输入卡密"];
        return;
    }
    [self.spinner startAnimating];
    self.spinner.hidden = NO;
    self.submitBtn.enabled = NO;
    [self verifyCardKey:cardKey];
}

- (void)verifyCardKey:(NSString *)cardKey {
    NSString *deviceId = [self getDeviceId];
    NSString *urlString = [NSString stringWithFormat:@"%@?action=verify&cardKey=%@&deviceId=%@", 
                          BACKEND_URL, 
                          [cardKey stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                          [deviceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.spinner.hidden = YES;
            self.submitBtn.enabled = YES;
            
            if (error) {
                NSString *errorMsg = [NSString stringWithFormat:@"网络错误: %@", error.localizedDescription];
                [self showAlert:errorMsg];
                return;
            }
            
            if (data) {
                NSError *jsonError;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (!jsonError) {
                    if ([json[@"success"] boolValue]) {
                        isVerified = YES;
                        hasShownAlert = YES;
                        authToken = json[@"token"];
                        [self saveToken:authToken];
                        
                        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.plugin.cardkey"];
                        [defaults setBool:YES forKey:IS_VERIFIED_KEY];
                        [defaults setBool:YES forKey:HAS_SHOWN_ALERT_KEY];
                        [defaults synchronize];
                        
                        [self dismissAlert];
                    } else {
                        [self showAlert:json[@"message"] ?: @"卡密验证失败"];
                    }
                } else {
                    NSString *responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [self showAlert:[NSString stringWithFormat:@"响应解析错误: %@", responseStr]];
                }
            } else {
                [self showAlert:@"网络错误: 无响应数据"];
            }
        });
    }];
    [task resume];
}

- (void)verifyToken:(NSString *)token {
    NSString *urlString = [NSString stringWithFormat:@"%@?action=checkStatus&token=%@", 
                          BACKEND_URL, 
                          [token stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && !error) {
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!jsonError && [json[@"success"] boolValue]) {
                isVerified = YES;
                hasShownAlert = YES;
                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.plugin.cardkey"];
                [defaults setBool:YES forKey:IS_VERIFIED_KEY];
                [defaults setBool:YES forKey:HAS_SHOWN_ALERT_KEY];
                [defaults synchronize];
            } else {
                [[NSFileManager defaultManager] removeItemAtPath:TOKEN_PATH error:nil];
                isVerified = NO;
                hasShownAlert = NO;
                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.plugin.cardkey"];
                [defaults setBool:NO forKey:IS_VERIFIED_KEY];
                [defaults setBool:NO forKey:HAS_SHOWN_ALERT_KEY];
                [defaults synchronize];
            }
        }
    }];
    [task resume];
}

- (void)saveToken:(NSString *)token {
    NSData *tokenData = [token dataUsingEncoding:NSUTF8StringEncoding];
    [tokenData writeToFile:TOKEN_PATH atomically:YES];
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @(TOKEN_PERMS)} ofItemAtPath:TOKEN_PATH error:nil];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissAlert {
    [UIView animateWithDuration:0.3 animations:^{
        self.overlayView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.overlayView removeFromSuperview];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

@end

static void showCardKeyAlert() {
    if (hasShownAlert || isVerified) return;
    hasShownAlert = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        
        for (UIScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow) break;
            }
        }
        
        if (!keyWindow) {
            for (UIWindow *window in [UIApplication sharedApplication].windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
        }
        
        if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (keyWindow && keyWindow.rootViewController) {
            CardKeyViewController *cardKeyVC = [[CardKeyViewController alloc] init];
            cardKeyVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
            [keyWindow.rootViewController presentViewController:cardKeyVC animated:NO completion:nil];
        }
    });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!hasShownAlert && !isVerified) {
        NSString *className = NSStringFromClass([self class]);
        if (className && ![className hasPrefix:@"CardKey"]) {
            showCardKeyAlert();
        }
    }
}
%end

%ctor {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.plugin.cardkey"];
    isVerified = [defaults boolForKey:IS_VERIFIED_KEY];
    hasShownAlert = [defaults boolForKey:HAS_SHOWN_ALERT_KEY];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:TOKEN_PATH]) {
        NSString *token = [NSString stringWithContentsOfFile:TOKEN_PATH encoding:NSUTF8StringEncoding error:nil];
        if (token && token.length > 0) {
            authToken = token;
            if (!isVerified) {
                isVerified = YES;
                hasShownAlert = YES;
                [defaults setBool:YES forKey:IS_VERIFIED_KEY];
                [defaults setBool:YES forKey:HAS_SHOWN_ALERT_KEY];
                [defaults synchronize];
            }
        } else {
            [fm removeItemAtPath:TOKEN_PATH error:nil];
            isVerified = NO;
            hasShownAlert = NO;
            [defaults setBool:NO forKey:IS_VERIFIED_KEY];
            [defaults setBool:NO forKey:HAS_SHOWN_ALERT_KEY];
            [defaults synchronize];
        }
    } else {
        if (isVerified || hasShownAlert) {
            isVerified = NO;
            hasShownAlert = NO;
            [defaults setBool:NO forKey:IS_VERIFIED_KEY];
            [defaults setBool:NO forKey:HAS_SHOWN_ALERT_KEY];
            [defaults synchronize];
        }
    }
    
    if (!hasShownAlert && !isVerified) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showCardKeyAlert();
        });
    }
}
