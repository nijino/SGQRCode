//
//  WBQRCodeVC.m
//  SGQRCodeExample
//
//  Created by kingsic on 2018/2/8.
//  Copyright © 2018年 kingsic. All rights reserved.
//

#import "WBQRCodeVC.h"
#import "SGQRCode.h"
#import "WebViewController.h"

@interface WBQRCodeVC ()<SGScanCodeDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    SGScanCode *scanCode;
}
@property (nonatomic, strong) SGScanView *scanView;
@property (nonatomic, strong) UILabel *promptLabel;

@end

@implementation WBQRCodeVC

- (void)dealloc {
    NSLog(@"WBQRCodeVC - dealloc");
    
    [self stop];
}

- (void)start {
    [scanCode startRunning];
    [self.scanView startScanning];
}

- (void)stop {
    [scanCode stopRunning];
    [self.scanView stopScanning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self start];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor blackColor];
    
    [self configureNav];
    
    [self configureUI];
    
    [self configureQRCode];
}

- (void)configureUI {
    [self.view addSubview:self.scanView];
    [self.view addSubview:self.promptLabel];
}

- (void)configureQRCode {
    scanCode = [SGScanCode scanCode];
    scanCode.preview = self.view;
    scanCode.delegate = self;
    CGFloat w = 0.7;
    CGFloat x = 0.5 * (1 - w);
    CGFloat h = (self.view.frame.size.width / self.view.frame.size.height) * w;
    CGFloat y = 0.5 * (1 - h);
    /// 扫描范围。对应辅助扫描框的frame（borderFrame）设置
    scanCode.rectOfInterest = CGRectMake(y, x, h, w);
}

- (void)scanCode:(SGScanCode *)scanCode result:(NSString *)result {
    [self stop];
    
    [scanCode playSoundEffect:@"SGQRCode.bundle/scan_end_sound.caf"];

    WebViewController *jumpVC = [[WebViewController alloc] init];
    jumpVC.comeFromVC = ComeFromWB;
    [self.navigationController pushViewController:jumpVC animated:YES];

    if ([result hasPrefix:@"http"]) {
        jumpVC.jump_URL = result;
    } else {
        jumpVC.jump_bar_code = result;
    }
}

- (void)configureNav {
    self.navigationItem.title = @"扫一扫";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"相册" style:(UIBarButtonItemStyleDone) target:self action:@selector(rightBarButtonItenAction)];
}

- (void)rightBarButtonItenAction {
    [SGPermission permissionWithType:SGPermissionTypePhoto completion:^(SGPermission * _Nonnull permission, SGPermissionStatus status) {
        if (status == SGPermissionStatusNotDetermined) {
            [permission request:^(BOOL granted) {
                if (granted) {
                    NSLog(@"第一次授权成功");
                    [self _enterImagePickerController];
                } else {
                    NSLog(@"第一次授权失败");
                }
            }];
        } else if (status == SGPermissionStatusAuthorized) {
            NSLog(@"SGPermissionStatusAuthorized");
            [self _enterImagePickerController];
        } else if (status == SGPermissionStatusDenied) {
            NSLog(@"SGPermissionStatusDenied");
            NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
            NSString *app_Name = [infoDict objectForKey:@"CFBundleDisplayName"];
            if (app_Name == nil) {
                app_Name = [infoDict objectForKey:@"CFBundleName"];
            }
            
            NSString *messageString = [NSString stringWithFormat:@"[前往：设置 - 隐私 - 照片 - %@] 允许应用访问", app_Name];
            UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"温馨提示" message:messageString preferredStyle:(UIAlertControllerStyleAlert)];
            UIAlertAction *alertA = [UIAlertAction actionWithTitle:@"确定" style:(UIAlertActionStyleDefault) handler:nil];
            
            [alertC addAction:alertA];
            [self presentViewController:alertC animated:YES completion:nil];
        } else if (status == SGPermissionStatusRestricted) {
            NSLog(@"SGPermissionStatusRestricted");
            UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"温馨提示" message:@"由于系统原因, 无法访问相册" preferredStyle:(UIAlertControllerStyleAlert)];
            UIAlertAction *alertA = [UIAlertAction actionWithTitle:@"确定" style:(UIAlertActionStyleDefault) handler:nil];
            [alertC addAction:alertA];
            [self presentViewController:alertC animated:YES completion:nil];
        }
    }];
}

- (void)_enterImagePickerController {
    [self stop];

    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    imagePicker.modalPresentationStyle = UIModalPresentationCustom;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark - - UIImagePickerControllerDelegate 的方法
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self start];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [scanCode readQRCode:image completion:^(NSString *result) {
        if (result == nil) {
            [self dismissViewControllerAnimated:YES completion:nil];
            [self start];
            NSLog(@"未识别出二维码");
        } else {
            [self dismissViewControllerAnimated:YES completion:^{
                WebViewController *jumpVC = [[WebViewController alloc] init];
                jumpVC.comeFromVC = ComeFromWB;
                [self.navigationController pushViewController:jumpVC animated:YES];
                
                if ([result hasPrefix:@"http"]) {
                    jumpVC.jump_URL = result;
                } else {
                    jumpVC.jump_bar_code = result;
                }
            }];
        }
    }];
}

- (SGScanView *)scanView {
    if (!_scanView) {
        SGScanViewConfigure *configure = [[SGScanViewConfigure alloc] init];
        configure.cornerColor = [UIColor orangeColor];
        configure.isFromTop = YES;
        // 打开辅助扫描框
        configure.isShowBorder = YES;
        configure.scanlineStep = 3;
        configure.scanline = @"SGQRCode.bundle/scan_scanline_wb";

        CGFloat x = 0;
        CGFloat y = 0;
        CGFloat w = self.view.frame.size.width;
        CGFloat h = self.view.frame.size.height;
        _scanView = [[SGScanView alloc] initWithFrame:CGRectMake(x, y, w, h) configure:configure];
    }
    return _scanView;
}

- (UILabel *)promptLabel {
    if (!_promptLabel) {
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.backgroundColor = [UIColor clearColor];
        CGFloat promptLabelX = 0;
        CGFloat promptLabelY = 0.73 * self.view.frame.size.height;
        CGFloat promptLabelW = self.view.frame.size.width;
        CGFloat promptLabelH = 25;
        _promptLabel.frame = CGRectMake(promptLabelX, promptLabelY, promptLabelW, promptLabelH);
        _promptLabel.textAlignment = NSTextAlignmentCenter;
        _promptLabel.font = [UIFont boldSystemFontOfSize:13.0];
        _promptLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
        _promptLabel.text = @"将二维码/条码放入框内, 即可自动扫描";
    }
    return _promptLabel;
}

@end
