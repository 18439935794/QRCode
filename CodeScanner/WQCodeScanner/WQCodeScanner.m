

#import "WQCodeScanner.h"
#import "resultViewController.h"
#import <AVFoundation/AVFoundation.h>
@interface WQCodeScanner ()<AVCaptureMetadataOutputObjectsDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    int num;
    BOOL upOrdown;
}
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, assign) BOOL isReading;

@property (nonatomic, assign) UIStatusBarStyle originStatusBarStyle;

@property (nonatomic, strong) UIImageView *lineImageView;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, strong) UIView *localImage;

//@property (nonatomic, strong) UIView *localImage;

@end

@implementation WQCodeScanner

- (id)init {
    self = [super init];
    if (self) {
        self.scanType = WQCodeScannerTypeAll;
    }
    return self;
}

- (void)dealloc {
    _session = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self configView];
    [self loadCustomView];
    
    // 判断权限（请求相机权限）
    // 请求权限的参数mediaType只能是AVMediaTypeVideo或者AVMediaTypeAudio，传其它类型会抛出异常，前者就是相机权限（摄像头），后者是音频（麦克风），也就是麦克风权限。
    // completionHandler是分线程的回调，授权以后创建界面的操作要回到主线程，否则点完确定要等一阵子界面才加载出来。
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
        
            if (granted) {
                [self loadScanView];

            } else {
                NSString *title = @"请在iPhone的”设置-隐私-相机“选项中，允许App访问你的相机";
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:@"" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil];
                [alertView show];
            }
            
        });
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.originStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    
    NSString *codeStr = @"";
    switch (_scanType) {
        case WQCodeScannerTypeAll: codeStr = @"二维码/条码"; break;
        case WQCodeScannerTypeQRCode: codeStr = @"二维码"; break;
        case WQCodeScannerTypeBarcode: codeStr = @"条码"; break;
        default: break;
    }
    
    //title
    if (self.titleStr && self.titleStr.length > 0) {
        self.titleLabel.text = self.titleStr;
    } else {
        self.titleLabel.text = codeStr;
    }
    
    //tip
    if (self.tipStr && self.tipStr.length > 0) {
        self.tipLabel.text = self.tipStr;
    } else {
        self.tipLabel.text= [NSString stringWithFormat:@"将%@放入框内，即可自动扫描", codeStr];
    }

    [self startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] setStatusBarStyle:self.originStatusBarStyle animated:YES];
    
    [self stopRunning];
    
    [super viewWillDisappear:animated];
}

/**
 创建扫描界面
 */
- (void)loadScanView {
    //获取摄像设备 AVMediaTypeVideo 摄像头 default默认后置
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //创建输入流 即 输入设置 采集摄像头捕捉到的信息
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //创建输出流 即 输出设备 解析输入设备采集到的信息
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc]init];
    //设置输出设备的代理 返回解析后的数据 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    //创建会话
    self.session = [[AVCaptureSession alloc]init];
   
    //关联 会话和设备
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
        
    }
    if ([self.session canAddOutput:output]) {
        [self.session addOutput:output];
        
    }
    //设置扫码支持的编码格式
    switch (self.scanType) {
        case WQCodeScannerTypeAll://二维码和条形码
            output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,
                                         AVMetadataObjectTypeEAN13Code,
                                         AVMetadataObjectTypeEAN8Code,
                                         AVMetadataObjectTypeUPCECode,
                                         AVMetadataObjectTypeCode39Code,
                                         AVMetadataObjectTypeCode39Mod43Code,
                                         AVMetadataObjectTypeCode93Code,
                                         AVMetadataObjectTypeCode128Code,
                                         AVMetadataObjectTypePDF417Code];
            break;
            
        case WQCodeScannerTypeQRCode://二维码
            output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode];
            break;
            
        case WQCodeScannerTypeBarcode://条形码
            output.metadataObjectTypes=@[AVMetadataObjectTypeEAN13Code,
                                         AVMetadataObjectTypeEAN8Code,
                                         AVMetadataObjectTypeUPCECode,
                                         AVMetadataObjectTypeCode39Code,
                                         AVMetadataObjectTypeCode39Mod43Code,
                                         AVMetadataObjectTypeCode93Code,
                                         AVMetadataObjectTypeCode128Code,
                                         AVMetadataObjectTypePDF417Code];
            break;

        default:
            break;
    }
    // 扫描框大小(AVCaptureSessionPreset640x480)  高质量采集率 (AVCaptureSessionPresetHigh)
    [self.session setSessionPreset:AVCaptureSessionPreset640x480];
    /**  layer (特殊图层 能够展示摄像头采集到的画面) 展示输入设备采集到的信息 */
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    layer.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:layer atIndex:0];
    // 开始捕获
    [self startRunning];
    
    //设置采集扫描区域的比例 默认全屏是（0，0，1，1）
    // 方法二：
    
    CGRect rect = CGRectMake((self.view.frame.size.width - 250) / 2, (self.view.frame.size.height - 250 - 72)/2, 250, 250);
    // 把一个在layer坐标系中的rect 转换成 一个在metadataoutputs坐标系中的rect。这个方法需要的rect参数是我们系统坐标系中的rect.
    CGRect intertRect = [layer metadataOutputRectOfInterestForRect:rect];
    // 把_captureOutput.rectOfInterest坐标系转成 layer 的坐标系的rect。
    CGRect layerRect = [layer rectForMetadataOutputRectOfInterest:intertRect];
    
    NSLog(@"------- %@,  %@",NSStringFromCGRect(intertRect),NSStringFromCGRect(layerRect));
    // rectOfInterest: 设置元数据识别搜索的区域。 这个属性的CGRect,四个值都需要在0~1之间。
//    output.rectOfInterest = intertRect;
    
    
    // 方法二：
    //rectOfInterest 填写的是一个比例，输出流视图preview.frame为 x , y, w, h, 要设置的矩形快的scanFrame 为 x1, y1, w1, h1. 那么rectOfInterest 应该设置为 CGRectMake(y1/y, x1/x, h1/h, w1/w)。
    CGRect rc = [[UIScreen mainScreen] bounds];
    CGFloat x = _width/ (self.view.frame.size.width);
    CGFloat y = _height/ (self.view.frame.size.height);
    CGFloat width = (rc.size.width - _width - _width)/ (self.view.frame.size.width);
    CGFloat height = (rc.size.height - _height - _height)/ (self.view.frame.size.height);
    output.rectOfInterest = CGRectMake(y, x, height, width);


}
- (void)startRunning {
    if (self.session) {
        _isReading = YES;
        
        [self.session startRunning];
        
        _timer=[NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(moveUpAndDownLine) userInfo:nil repeats: YES];
    }
}

- (void)stopRunning {
    if ([_timer isValid]) {
        [_timer invalidate];
        _timer = nil ;
    }
    
    [self.session stopRunning];
}

- (void)pressBackButton {
    UINavigationController *nvc = self.navigationController;
    if (nvc) {
        if (nvc.viewControllers.count == 1) {
            [nvc dismissViewControllerAnimated:YES completion:nil];
        } else {
            [nvc popViewControllerAnimated:NO];
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


//二维码的横线移动
- (void)moveUpAndDownLine {
    
    if (upOrdown == NO) {
        num ++;
        CGRect frame = self.lineImageView.frame;
        frame.origin.y = TOP+10+2*num;
        self.lineImageView.frame = frame;
        if (2*num == 200) {
            upOrdown = YES;
        }

    }
    else {
        num --;
        CGRect frame = self.lineImageView.frame;
        frame.origin.y = TOP+10+2*num;
        self.lineImageView.frame = frame;
        if (num == 0) {
            upOrdown = NO;
        }

    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
// 扫描出结果后就会调用的方法
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (!_isReading) {
        return;
    }
    if (metadataObjects.count > 0) {
        //震动
        // TODO: 
        [self playBeep];
        //停止扫描
        _isReading = NO;
        AVMetadataMachineReadableCodeObject *metadataObject = metadataObjects[0];
        NSString *result = metadataObject.stringValue;//获取到二维码中的信息字符串
        
        if (self.resultBlock) {
            self.resultBlock(result?:@"");
        }
       // 扫描框消失
        [self pressBackButton];
    }
}
//音效震动
- (void)playBeep
{
    SystemSoundID soundID;
    
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"滴-2"ofType:@"mp3"]], &soundID);
    
    AudioServicesPlaySystemSound(soundID);
    
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

#pragma mark 读取图片二维码
/**
 *  读取图片中二维码信息
 *
 *  @param image 图片
 *
 *  @return 二维码内容
 */
+(NSString *)readQRCodeFromImage:(UIImage *)image{
    NSData *data = UIImagePNGRepresentation(image);
    CIImage *ciimage = [CIImage imageWithData:data];
    if (ciimage) {
        CIDetector *qrDetector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:[CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@(YES)}] options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh}];
        NSArray *resultArr = [qrDetector featuresInImage:ciimage];
        if (resultArr.count >0) {
            CIFeature *feature = resultArr[0];
            CIQRCodeFeature *qrFeature = (CIQRCodeFeature *)feature;
            NSString *result = qrFeature.messageString;
            
            return result;
        }else{
            return nil;
        }
    }else{
        return nil;
    }
}
#pragma mark 生成二维码
/**
 *  生成二维码图片
 *
 *  @param QRString  二维码内容
 *  @param sizeWidth 图片size（正方形）
 *  @param color     填充色
 *
 *  @return  二维码图片
 */
+(UIImage *)createQRimageString:(NSString *)QRString sizeWidth:(CGFloat)sizeWidth fillColor:(UIColor *)color{
    CIImage *ciimage = [self createQRForString:QRString];
    UIImage *qrcode = [self createNonInterpolatedUIImageFormCIImage:ciimage withSize:sizeWidth];
    if (color) {
        CGFloat R, G, B;
        
        CGColorRef colorRef = [color CGColor];
        long numComponents = CGColorGetNumberOfComponents(colorRef);
        
        if (numComponents == 4)
        {
            const CGFloat *components = CGColorGetComponents(colorRef);
            R = components[0];
            G = components[1];
            B = components[2];
        }
        
        UIImage *customQrcode = [self imageBlackToTransparent:qrcode withRed:R andGreen:G andBlue:B];
        return customQrcode;
    }
    
    return qrcode;
    
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


#pragma mark - QRCodeGenerator
+ (CIImage *)createQRForString:(NSString *)qrString {
    // Need to convert the string to a UTF-8 encoded NSData object
    NSData *stringData = [qrString dataUsingEncoding:NSUTF8StringEncoding];
    // Create the filter
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // Set the message content and error-correction level
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"M" forKey:@"inputCorrectionLevel"];
    // Send the image back
    return qrFilter.outputImage;
}
#pragma mark - InterpolatedUIImage
+ (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat) size {
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    // create a bitmap image that we'll draw into a bitmap context at the desired size;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    // Create an image with the contents of our bitmap
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    // Cleanup
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    return [UIImage imageWithCGImage:scaledImage];
}
#pragma mark - imageToTransparent
void ProviderReleaseData (void *info, const void *data, size_t size){
    free((void*)data);
}
+ (UIImage*)imageBlackToTransparent:(UIImage*)image withRed:(CGFloat)red andGreen:(CGFloat)green andBlue:(CGFloat)blue{
    const int imageWidth = image.size.width;
    const int imageHeight = image.size.height;
    size_t      bytesPerRow = imageWidth * 4;
    uint32_t* rgbImageBuf = (uint32_t*)malloc(bytesPerRow * imageHeight);
    // create context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbImageBuf, imageWidth, imageHeight, 8, bytesPerRow, colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, imageWidth, imageHeight), image.CGImage);
    // traverse pixe
    int pixelNum = imageWidth * imageHeight;
    uint32_t* pCurPtr = rgbImageBuf;
    for (int i = 0; i < pixelNum; i++, pCurPtr++){
        if ((*pCurPtr & 0xFFFFFF00) < 0x99999900){
            // change color
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[3] = red; //0~255
            ptr[2] = green;
            ptr[1] = blue;
        }else{
            uint8_t* ptr = (uint8_t*)pCurPtr;
            ptr[0] = 0;
        }
    }
    // context to image
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, rgbImageBuf, bytesPerRow * imageHeight, ProviderReleaseData);
    CGImageRef imageRef = CGImageCreate(imageWidth, imageHeight, 8, 32, bytesPerRow, colorSpace,
                                        kCGImageAlphaLast | kCGBitmapByteOrder32Little, dataProvider,
                                        NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    UIImage* resultUIImage = [UIImage imageWithCGImage:imageRef];
    // release
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    return resultUIImage;
}
- (void)loadCustomView {
    self.view.backgroundColor = [UIColor blackColor];
    
    CGRect rc = [[UIScreen mainScreen] bounds];
    //rc.size.height -= 50;
    _width = rc.size.width * 0.2;
    //height = rc.size.height * 0.2;
    _height = (rc.size.height - (rc.size.width - _width * 2))/2;
    
    CGFloat alpha = 0.5;
    
    //最上部view
    UIView* upView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, rc.size.width, _height)];
    upView.alpha = alpha;
    upView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:upView];
    
    //左侧的view
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, _height, _width, rc.size.height - _height * 2)];
    leftView.alpha = alpha;
    leftView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:leftView];
    
    //中间扫描区域
    UIImageView *scanCropView=[[UIImageView alloc] initWithFrame:CGRectMake(_width, _height, rc.size.width - _width - _width, rc.size.height - _height - _height)];
    scanCropView.image=[UIImage imageNamed:@"pick_bg"];
    scanCropView. backgroundColor =[ UIColor clearColor ];
    [self.view addSubview :scanCropView];
    
    //右侧的view
    UIView *rightView = [[UIView alloc] initWithFrame:CGRectMake(rc.size.width - _width, _height, _width, rc.size.height - _height * 2)];
    rightView.alpha = alpha;
    rightView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:rightView];
    
    //底部view
    UIView *downView = [[UIView alloc] initWithFrame:CGRectMake(0, rc.size.height - _height, rc.size.width, _height)];
    downView.alpha = alpha;
    downView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:downView];
    
    //用于说明的label
    self.tipLabel= [[UILabel alloc] init];
    self.tipLabel.backgroundColor = [UIColor clearColor];
    self.tipLabel.frame=CGRectMake(_width, rc.size.height - _height, rc.size.width - _width * 2, 40);
    self.tipLabel.numberOfLines=0;
    self.tipLabel.textColor=[UIColor whiteColor];
    self.tipLabel.textAlignment = NSTextAlignmentCenter;
    self.tipLabel.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:self.tipLabel];
    
    //画中间的基准线
    self.lineImageView = [[UIImageView alloc] initWithFrame:CGRectMake (_width, _height, rc.size.width - 2 * _width, 2)];
    self.lineImageView.image = [UIImage imageNamed:@"line"];
    [self.view addSubview:self.lineImageView];
    
    
    //标题
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 20, rc.size.width - 50 - 50, 44)];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.titleLabel];
    
    //返回
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 20, 44, 44)];
    [backButton setImage:[UIImage imageNamed:@"wq_code_scanner_back"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(pressBackButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
    
    upOrdown = NO;
    num =0;
}
@end
