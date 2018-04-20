

#import "ViewController.h"
#import "WQCodeScanner.h"
#import "resultViewController.h"
@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //扫描按钮
    UIButton * scanBtn = [self createBtnWithFrame:CGRectMake((SCREEN_WIDTH - 300)/2, 100, 300, 50) title:@"开始扫描"];
    [scanBtn addTarget:self action:@selector(pressButton) forControlEvents:UIControlEventTouchUpInside];
    //扫描本地图片
    UIButton * scanLocalBtn = [self createBtnWithFrame:CGRectMake((SCREEN_WIDTH - 300)/2, 200, 300, 50) title:@"扫描本地图片"];
    [scanLocalBtn addTarget:self action:@selector(pressLocalButton) forControlEvents:UIControlEventTouchUpInside];
    //生成二维码
    UIButton * buildCodesBtn = [self createBtnWithFrame:CGRectMake((SCREEN_WIDTH - 300)/2, 280, 300, 50) title:@"生成二维码"];
    [buildCodesBtn addTarget:self action:@selector(buildCodesButton) forControlEvents:UIControlEventTouchUpInside];

    
}

/**
 扫描
 */
- (void)pressButton {
    WQCodeScanner *scanner = [[WQCodeScanner alloc] init];
    [self presentViewController:scanner animated:YES completion:nil];
    scanner.resultBlock = ^(NSString *value) {
       
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"扫描结果" message:value delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alert show];
        
    };
}
/**
 扫描本地
 */
- (void)pressLocalButton {
   
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        UIImagePickerController * _imagePickerController = [[UIImagePickerController alloc] init];
        _imagePickerController.delegate = self;
        _imagePickerController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
        _imagePickerController.allowsEditing = YES;
        _imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:_imagePickerController animated:YES completion:nil];
    }else{
        NSLog(@"不支持访问相册");
    }
    
//
//    NSString *result = [WQCodeScanner readQRCodeFromImage:[UIImage imageNamed:@"zsRC"]];//@"QRImage"]];
//    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:result message:@"" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//    [alertView show];


}
/**
 生成二维码
 */
- (void)buildCodesButton {
    
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @""
                                                                              message: @"输入地址"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = @"https://www.pgyer.com/zsRC";
        textField.textColor = [UIColor blueColor];
        textField.borderStyle = UITextBorderStyleNone;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"立即生成" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        for (UIView * v in self.view.subviews) {
            if ([v isKindOfClass:[UIImageView class]]) {
                [v removeFromSuperview];
            }
        }
        NSArray * textfields = alertController.textFields;
        UITextField * namefield = textfields[0];
        UIImage * image = [WQCodeScanner createQRimageString:namefield.text sizeWidth:200.0 fillColor:[UIColor redColor]];
        UIImageView * imgV = [[UIImageView alloc]initWithImage:image];
        imgV.frame = CGRectMake((SCREEN_WIDTH - 200)/2, 350, 200, 200);
        [self.view addSubview:imgV];

    }]];
    [self presentViewController:alertController animated:YES completion:nil];

}
//选中图片的回调
-(void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *content = @"" ;
    //取出选中的图片
    UIImage *pickImage = info[UIImagePickerControllerOriginalImage];
    NSData *imageData = UIImagePNGRepresentation(pickImage);
    CIImage *ciImage = [CIImage imageWithData:imageData];
    
    //创建探测器
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyLow}];
    NSArray *feature = [detector featuresInImage:ciImage];
    
    //取出探测到的数据
    for (CIQRCodeFeature *result in feature) {
        content = result.messageString;
    }
    
    //选中图片后先返回扫描页面，然后跳转到新页面进行展示
    [picker dismissViewControllerAnimated:NO completion:^{
        
        if (![content isEqualToString:@""]) {
           
            [self createAlertWithContent:content];
        }else{
            NSLog(@"没有扫描结果");
        }
    }];
    
    
}
- (void)createAlertWithContent:(NSString *)content {
    
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"扫描结果"
                                                                              message: content
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"打开链接" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        //将扫描到的链接进行处理
        resultViewController *result = [[resultViewController alloc]init];
        result.content = content;
        [self.navigationController pushViewController:result animated:YES];
        
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}
/**
 创建按钮

 @param frame frame
 @param title title
 @return button
 */
- (UIButton * )createBtnWithFrame:(CGRect)frame  title:(NSString *)title {
    UIButton *button = [[UIButton alloc] initWithFrame:frame];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = [UIColor cyanColor];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    return button;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
