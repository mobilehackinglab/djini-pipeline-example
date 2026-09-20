//
//  ViewController.m
//  Linkliar
//
//  Created by vi on 01/10/25.
//

#import "ViewController.h"
#include <string.h>
#include <stdio.h>

@interface ViewController ()

@property (strong, nonatomic) NSArray *maliciousKeywords;
@property (strong, nonatomic) NSArray *phishingKeywords;
@property (nonatomic) BOOL debugModeEnabled;
@property (strong, nonatomic) NSString *debugURL;

- (void)performMainURLScan:(NSURLComponents *)urlComponents;
- (void)sendDebugReportToURLWithCompletion:(NSString *)urlString completion:(void(^)(void))completion;
- (void)sendDebugReport:(NSArray *)debugData toURL:(NSString *)urlString completion:(void(^)(void))completion;

@end


int headerValidator(const char* header, const char* value);
int flag(const char* header, const char* value);

int headerValidator(const char* header, const char* value) {
    if (strlen(header) >= 32) {
        return 0;
    }

    if (strlen(value) >= 256) {
        return 0;
    }

    return 1;
}

int flag(const char* header, const char* value) {
    if (strlen(header) > 31) {
        NSString *debugURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"DebugURL"];
        
        if (debugURL) {
            NSURL *url = [NSURL URLWithString:debugURL];
            if (url) {
                
                char part1[] = "MHL{h34d3r_";
                char part2[] = "s0_l0ng_th4";
                char part3[] = "t_1t_0v3rfl0ws}";
                char flagBuffer[64];
                
                
                snprintf(flagBuffer, sizeof(flagBuffer), "%s%s%s", part1, part2, part3);
                NSString *flagString = [NSString stringWithUTF8String:flagBuffer];
                
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                request.HTTPMethod = @"POST";
                [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                
                NSDictionary *payload = @{ @"flag": flagString };
                NSError *error;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
                
                if (!error) {
                    request.HTTPBody = jsonData;
                    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request];
                    [task resume];
                }
            }
        }
        return 1;
    }
    return 0;
}

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupMaliciousKeywords];
    [self loadDebugMode];
    [self setupSettingsButton];
    
    self.urlTextField.delegate = self;
}

- (void)setupUI {
    self.urlTextField.placeholder = @"Enter URL to verify (e.g., https://example.com)";
    self.urlTextField.keyboardType = UIKeyboardTypeURL;
    self.urlTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlTextField.autocorrectionType = UITextAutocorrectionTypeNo;

    self.resultLabel.numberOfLines = 0;
    self.resultLabel.textAlignment = NSTextAlignmentCenter;
    self.resultLabel.text = @"Enter a URL above and tap 'Scan URL' to verify its safety";

    [self.scanButton setTitle:@"Scan URL" forState:UIControlStateNormal];
    self.scanButton.backgroundColor = [UIColor systemBlueColor];
    [self.scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.scanButton.layer.cornerRadius = 8.0;

    self.activityIndicator.hidesWhenStopped = YES;

    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.text = @"Mobile Hacking Lab";
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.textColor = [UIColor grayColor];
    footerLabel.font = [UIFont systemFontOfSize:14.0];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:footerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [footerLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [footerLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (void)setupSettingsButton {
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gear"]
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self
                                                                       action:@selector(showSettings:)];
    self.navigationItem.rightBarButtonItem = settingsButton;
}

- (void)showSettings:(id)sender {
    UIAlertController *settingsAlert = [UIAlertController alertControllerWithTitle:@"Settings"
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
    
    
    if (self.debugModeEnabled) {
        NSString *debugMessage = [NSString stringWithFormat:@"Debug Mode: ON\nURL: %@", self.debugURL ?: @"Not set"];
        UIAlertAction *disableDebugAction = [UIAlertAction actionWithTitle:@"Disable Debug Mode"
                                                                     style:UIAlertActionStyleDestructive
                                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                                       [self disableDebugMode];
                                                                   }];
        
        
        UIAlertAction *debugInfoAction = [UIAlertAction actionWithTitle:debugMessage
                                                                  style:UIAlertActionStyleDefault
                                                                handler:nil];
        debugInfoAction.enabled = NO; 
        
        [settingsAlert addAction:debugInfoAction];
        [settingsAlert addAction:disableDebugAction];
    } else {
        UIAlertAction *debugInfoAction = [UIAlertAction actionWithTitle:@"Debug Mode: OFF"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:nil];
        debugInfoAction.enabled = NO; 
        [settingsAlert addAction:debugInfoAction];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [settingsAlert addAction:cancelAction];
    
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        settingsAlert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    
    [self presentViewController:settingsAlert animated:YES completion:nil];
}

- (void)disableDebugMode {
    self.debugModeEnabled = NO;
    self.debugURL = nil;
    
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DebugModeEnabled"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DebugURL"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"Debug Mode Disabled"
                                                                          message:@"Debug mode has been turned off."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    [confirmAlert addAction:okAction];
    
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)setupMaliciousKeywords {
    self.maliciousKeywords = @[
        @"crack", @"jailbreak", @"keygen", @"mod", @"cracked",
        @"pirate", @"warez", @"nulled", @"patch", @"serial",
        @"activator", @"bypass", @"hack", @"exploit"
    ];
    
    self.phishingKeywords = @[
        @"you have won", @"congratulations", @"winner", @"prize",
        @"i am missing you", @"lonely", @"chat with me", @"meet singles",
        @"urgent", @"act now", @"limited time", @"expires today",
        @"click here now", @"claim your", @"free money", @"cash prize",
        @"nigerian prince", @"inheritance", @"lottery", @"sweepstakes",
        @"verify your account", @"suspended account", @"unusual activity",
        @"confirm identity", @"update payment", @"billing problem"
    ];
}

- (void)loadDebugMode {
    self.debugModeEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DebugModeEnabled"];
    self.debugURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"DebugURL"];
}

- (void)saveDebugMode {
    [[NSUserDefaults standardUserDefaults] setBool:self.debugModeEnabled forKey:@"DebugModeEnabled"];
    if (self.debugURL) {
        [[NSUserDefaults standardUserDefaults] setObject:self.debugURL forKey:@"DebugURL"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)scanURL:(id)sender {
    NSString *urlString = [self.urlTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (urlString.length == 0) {
        [self showResult:@"Please enter a URL to scan" isSecure:NO];
        return;
    }
    
    [self startScanning];
    [self validateAndScanURL:urlString];
}

- (void)startScanning {
    self.resultLabel.text = @"Scanning URL...";
    self.scanButton.enabled = NO;
    [self.activityIndicator startAnimating];
}

- (void)stopScanning {
    self.scanButton.enabled = YES;
    [self.activityIndicator stopAnimating];
}

- (void)validateAndScanURL:(NSString *)urlString {
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlString];
    
    if (!urlComponents || !urlComponents.scheme || !urlComponents.host) {
        [self stopScanning];
        [self showResult:@"[ERROR] Invalid URL format. Please enter a valid URL with protocol (http://or https://)" isSecure:NO];
        return;
    }
    
    
    if (self.debugModeEnabled && self.debugURL) {
        [self sendDebugReportToURLWithCompletion:self.debugURL completion:^{
            
            [self performMainURLScan:urlComponents];
        }];
    } else {
        
        [self performMainURLScan:urlComponents];
    }
}

- (void)performMainURLScan:(NSURLComponents *)urlComponents {
    BOOL isHTTPS = [urlComponents.scheme.lowercaseString isEqualToString:@"https"];
    NSURL *url = urlComponents.URL;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 10.0;
    request.HTTPMethod = @"GET";
    
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15" forHTTPHeaderField:@"User-Agent"];
    
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopScanning];
            
            if (error) {
                [self showResult:[NSString stringWithFormat:@"[ERROR] Connection Error: %@", error.localizedDescription] isSecure:NO];
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSString *responseString = @"";
            
            if (data) {
                responseString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
                if (!responseString) {
                    responseString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                }
            }

            
            [self parseHTTPHeaders:httpResponse];
            [self analyzeResponse:responseString httpResponse:httpResponse urlComponents:urlComponents isHTTPS:isHTTPS];
        });
    }];
    
    [task resume];
}



- (void)analyzeResponse:(NSString *)content httpResponse:(NSHTTPURLResponse *)httpResponse urlComponents:(NSURLComponents *)urlComponents isHTTPS:(BOOL)isHTTPS {
    NSMutableArray *warnings = [NSMutableArray array];
    NSMutableArray *positives = [NSMutableArray array];
    BOOL isSafe = YES;

    NSString *urlString = urlComponents.URL.absoluteString;
    if ([urlString.lowercaseString hasSuffix:@".ipa"]) {
        [warnings addObject:@"[DANGER] URL points to IPA file - potentially malicious iOS app"];
        isSafe = NO;
    }

    if (isHTTPS) {
        [positives addObject:@"[SECURE] Uses HTTPS encryption"];
    } else {
        [warnings addObject:@"[WARNING] Uses HTTP (not encrypted)"];
        isSafe = NO;
    }

    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        [positives addObject:[NSString stringWithFormat:@"[OK] Valid response (Status: %ld)", (long)httpResponse.statusCode]];
    } else if (httpResponse.statusCode >= 300 && httpResponse.statusCode < 400) {
        [warnings addObject:[NSString stringWithFormat:@"[WARNING] Redirect response (Status: %ld)", (long)httpResponse.statusCode]];
    } else {
        [warnings addObject:[NSString stringWithFormat:@"[ERROR] Error response (Status: %ld)", (long)httpResponse.statusCode]];
        isSafe = NO;
    }

    if (content && content.length > 0) {
        NSString *lowercaseContent = content.lowercaseString;
        NSString *currentHost = urlComponents.host.lowercaseString;

        NSMutableArray *foundKeywords = [NSMutableArray array];
        for (NSString *keyword in self.maliciousKeywords) {
            if ([lowercaseContent containsString:keyword.lowercaseString]) {
                [foundKeywords addObject:keyword];
            }
        }

        if (foundKeywords.count > 0) {
            [warnings addObject:[NSString stringWithFormat:@"[DANGER] Contains malicious keywords: %@", [foundKeywords componentsJoinedByString:@", "]]];
            isSafe = NO;
        }

        NSMutableArray *foundPhishingKeywords = [NSMutableArray array];
        for (NSString *keyword in self.phishingKeywords) {
            if ([lowercaseContent containsString:keyword.lowercaseString]) {
                [foundPhishingKeywords addObject:keyword];
            }
        }

        if (foundPhishingKeywords.count > 0) {
            [warnings addObject:[NSString stringWithFormat:@"[DANGER] Contains phishing keywords: %@", [foundPhishingKeywords componentsJoinedByString:@", "]]];
            isSafe = NO;
        }

        [self checkForClickjacking:lowercaseContent warnings:warnings positives:positives];
        [self checkForCSRF:content currentHost:currentHost warnings:warnings safe:&isSafe];

        [positives addObject:@"[OK] Content analysis completed"];
    } else {
        [warnings addObject:@"[WARNING] No content available for analysis"];
    }

    NSMutableString *result = [NSMutableString string];

    if (isSafe && warnings.count == 0) {
        [result appendString:@"[SAFE] URL APPEARS SAFE\n\n"];
    } else if (warnings.count > 0 && warnings.count <= 2) {
        [result appendString:@"[CAUTION] URL HAS WARNINGS\n\n"];
    } else {
        [result appendString:@"[DANGER] URL APPEARS DANGEROUS\n\n"];
    }

    if (positives.count > 0) {
        for (NSString *positive in positives) {
            [result appendFormat:@"%@\n", positive];
        }
        [result appendString:@"\n"];
    }

    if (warnings.count > 0) {
        for (NSString *warning in warnings) {
            [result appendFormat:@"%@\n", warning];
        }
    }

    [self showResult:result isSecure:isSafe];
}

- (void)checkForClickjacking:(NSString *)content warnings:(NSMutableArray *)warnings positives:(NSMutableArray *)positives {
    
    if ([content containsString:@"x-frame-options"] || 
        [content containsString:@"frame-ancestors"] ||
        [content containsString:@"framebuster"]) {
        [positives addObject:@"[SECURE] Has clickjacking protection"];
    } else {
        
        if ([content containsString:@"<iframe"] && 
            ([content containsString:@"opacity:0"] || 
             [content containsString:@"visibility:hidden"] ||
             [content containsString:@"position:absolute"])) {
            [warnings addObject:@"[WARNING] Suspicious iframe detected - possible clickjacking attempt"];
        }
    }
}

- (void)checkForCSRF:(NSString *)content currentHost:(NSString *)currentHost warnings:(NSMutableArray *)warnings safe:(BOOL *)isSafe {
    
    NSError *error;
    NSRegularExpression *formRegex = [NSRegularExpression regularExpressionWithPattern:@"<form[^>]*action=[\"']([^\"']*)[\"'][^>]*>" 
                                                                               options:NSRegularExpressionCaseInsensitive 
                                                                                 error:&error];
    
    if (error) return;
    
    NSArray *matches = [formRegex matchesInString:content options:0 range:NSMakeRange(0, content.length)];
    
    for (NSTextCheckingResult *match in matches) {
        if (match.numberOfRanges > 1) {
            NSRange actionRange = [match rangeAtIndex:1];
            NSString *actionURL = [content substringWithRange:actionRange];
            
            
            if ([actionURL hasPrefix:@"http"] && ![actionURL.lowercaseString containsString:currentHost]) {
                [warnings addObject:[NSString stringWithFormat:@"[WARNING] Form submits to external domain - possible CSRF: %@", actionURL]];
            }
        }
    }
}

- (void)parseHTTPHeaders:(NSHTTPURLResponse *)response {
    struct {
        char headerName[32];
        int (*validateFunc)(const char*, const char*);
        char headerValue[256];
    } responseHeaders[100];

    int headerCount = 0;
    NSDictionary *headerFields = response.allHeaderFields; 
    NSMutableArray *warnings = [NSMutableArray array]; 

    for (NSString *headerName in headerFields) {
        if (headerCount >= 100) break;

        NSString *headerValue = headerFields[headerName];
        const char* nameData = [headerName cStringUsingEncoding:NSISOLatin1StringEncoding];
        const char* valueData = [headerValue cStringUsingEncoding:NSISOLatin1StringEncoding];

        if (nameData && valueData) {
            responseHeaders[headerCount].validateFunc = headerValidator;

            int i = 0;
            while (nameData[i] != '\0') {
                responseHeaders[headerCount].headerName[i] = nameData[i];
                i++;
            }
            responseHeaders[headerCount].headerName[i] = '\0';

            strncpy(responseHeaders[headerCount].headerValue, valueData, sizeof(responseHeaders[headerCount].headerValue) - 1);
            responseHeaders[headerCount].headerValue[sizeof(responseHeaders[headerCount].headerValue) - 1] = '\0';

            int valid = responseHeaders[headerCount].validateFunc(responseHeaders[headerCount].headerName, responseHeaders[headerCount].headerValue);

            if (!valid) {
                [warnings addObject:@"[ERROR] Invalid header detected."];
            }

            headerCount++;
        }
    }
}

- (BOOL)isSuspiciousDomain:(NSString *)host {
    NSCharacterSet *numericSet = [NSCharacterSet decimalDigitCharacterSet];
    if ([host rangeOfCharacterFromSet:numericSet].location != NSNotFound) {
        return YES;
    }

    NSCharacterSet *specialCharacterSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    if ([host rangeOfCharacterFromSet:specialCharacterSet].location != NSNotFound) {
        return YES;
    }

    NSArray *components = [host componentsSeparatedByString:@"."];
    if (components.count > 3) {
        return YES;
    }

    return NO;
}

- (void)showResult:(NSString *)message isSecure:(BOOL)secure {
    self.resultLabel.text = message;
    
    if (secure) {
        self.resultLabel.textColor = [UIColor systemGreenColor];
    } else {
        self.resultLabel.textColor = [UIColor systemRedColor];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.urlTextField) {
        [self scanURL:nil];
        return YES;
    }
    return NO;
}

#pragma mark - Deeplink Support

- (void)scanURLFromDeeplink:(NSString *)urlString {
    
    if ([urlString hasPrefix:@"debug?"]) {
        [self handleDebugRequest:urlString];
        return;
    }
    
    
    NSString *decodedURL = [urlString stringByRemovingPercentEncoding];
    if (!decodedURL) {
        decodedURL = urlString;
    }
    
    self.urlTextField.text = decodedURL;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Scan"
                                                                   message:[NSString stringWithFormat:@"Scan URL?\n\n%@", decodedURL]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *scanAction = [UIAlertAction actionWithTitle:@"Scan Now"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
                                                           [self scanURL:nil];
                                                       }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:scanAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)enableDebugModeWithURL:(NSString *)debugURL {
    self.debugModeEnabled = YES;
    self.debugURL = debugURL;
    [self saveDebugMode];
}

- (void)handleDebugRequest:(NSString *)debugString {
    
    NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"debug://%@", debugString]];
    
    NSString *targetURL = nil;
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"url"]) {
            targetURL = item.value;
            break;
        }
    }
    
    if (!targetURL) {
        return;
    }
        
    [self enableDebugModeWithURL:targetURL];
    [self sendDebugReportToURLWithCompletion:targetURL completion:nil];
}

- (NSArray *)generateDebugReport {
    NSMutableArray *addresses = [NSMutableArray array];
    
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)headerValidator]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)flag]}];
    
    
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)[self methodForSelector:@selector(scanURL:)]]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)[self methodForSelector:@selector(validateAndScanURL:)]]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)[self methodForSelector:@selector(parseHTTPHeaders:)]]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)[self methodForSelector:@selector(analyzeResponse:httpResponse:urlComponents:isHTTPS:)]]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)[self methodForSelector:@selector(handleDebugRequest:)]]}];
    
    
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)malloc]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)free]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)printf]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)strcpy]}];
    [addresses addObject:@{@"addr": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)(uintptr_t)strlen]}];
    
    return [addresses copy];
}

- (void)sendDebugReportToURLWithCompletion:(NSString *)urlString completion:(void(^)(void))completion {
    NSArray *debugData = [self generateDebugReport];
    [self sendDebugReport:debugData toURL:urlString completion:completion];
}

- (void)sendDebugReport:(NSArray *)debugData toURL:(NSString *)urlString {
    [self sendDebugReport:debugData toURL:urlString completion:nil];
}

- (void)sendDebugReport:(NSArray *)debugData toURL:(NSString *)urlString completion:(void(^)(void))completion {   
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion();
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Linkliar/1.0 DebugAgent" forHTTPHeaderField:@"User-Agent"];
    
    NSError *error;
    NSDictionary *payload = @{
        @"debug_data": debugData, 
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"device": @"iOS",
        @"app": @"Linkliar"
    };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    
    if (error) {
        if (completion) completion();
        return;
    }
    
    request.HTTPBody = jsonData;
        
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request 
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        }
        
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    }];
    
    [task resume];
}

@end
