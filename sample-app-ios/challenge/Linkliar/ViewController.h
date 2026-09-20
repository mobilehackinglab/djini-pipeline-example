//
//  ViewController.h
//  Linkliar
//
//  Created by vi on 01/10/25.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *urlTextField;
@property (weak, nonatomic) IBOutlet UIButton *scanButton;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

- (IBAction)scanURL:(id)sender;
- (void)scanURLFromDeeplink:(NSString *)urlString;

@end

