// The MIT License (MIT)
//
// Copyright (c) 2014 Suyeol Jeon (http:xoul.kr)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import <objc/runtime.h>
#import "UITextView+Placeholder.h"

@implementation UITextView (Placeholder)

#pragma mark - Class Methods
#pragma mark `defaultPlaceholderColor`

+ (UIColor *)defaultPlaceholderColor {
    static UIColor *color = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UITextField *textField = [[UITextField alloc] init];
        textField.placeholder = @" ";
        color = [textField valueForKeyPath:@"_placeholderLabel.textColor"];
    });
    return color;
}

#pragma mark - UI Life cycle
// I know below iOS10, UITextView not override willMoveToSuperview and willMoveToWindow,
// but I am not sure father version still follow this rule.
- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (newSuperview == nil) {
        [self removeRegisterEvents];
    }
    else {
        [self registerEvents];
    }
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (newWindow == nil) {
        [self removeRegisterEvents];
    }
    else {
        [self registerEvents];
    }
}

#pragma mark - Properties:
#pragma mark -
#pragma mark `placeholderLabel`

- (UILabel *)placeholderLabel {
    UILabel *label = objc_getAssociatedObject(self, @selector(placeholderLabel));
    if (!label) {
        NSAttributedString *originalText = self.attributedText;
        self.text = @" "; // lazily set font of `UITextView`.
        self.attributedText = originalText;
        
        label = [[UILabel alloc] init];
        label.textColor = [self.class defaultPlaceholderColor];
        label.numberOfLines = 0;
        label.userInteractionEnabled = NO;
        objc_setAssociatedObject(self, @selector(placeholderLabel), label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        self.needsUpdateFont = YES;
        [self updatePlaceholderLabel];
        self.needsUpdateFont = NO;
        [self registerEvents];
    }
    return label;
}


#pragma mark `placeholder`

- (NSString *)placeholder {
    return self.placeholderLabel.text;
}

- (void)setPlaceholder:(NSString *)placeholder {
    self.placeholderLabel.text = placeholder;
    [self updatePlaceholderLabel];
}

- (NSAttributedString *)attributedPlaceholder {
    return self.placeholderLabel.attributedText;
}

- (void)setAttributedPlaceholder:(NSAttributedString *)attributedPlaceholder {
    self.placeholderLabel.attributedText = attributedPlaceholder;
    [self updatePlaceholderLabel];
}

#pragma mark `placeholderColor`

- (UIColor *)placeholderColor {
    return self.placeholderLabel.textColor;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    self.placeholderLabel.textColor = placeholderColor;
}


#pragma mark `needsUpdateFont`

- (BOOL)needsUpdateFont {
    return [objc_getAssociatedObject(self, @selector(needsUpdateFont)) boolValue];
}

- (void)setNeedsUpdateFont:(BOOL)needsUpdate {
    objc_setAssociatedObject(self, @selector(needsUpdateFont), @(needsUpdate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#pragma mark - Events
+ (NSArray *)observingKeys {
    return @[@"attributedText",
             @"bounds",
             @"font",
             @"frame",
             @"text",
             @"textAlignment",
             @"textContainerInset"];
}

- (BOOL)registerEvent {
    return [objc_getAssociatedObject(self, @selector(registerEvent)) boolValue];
}

- (void)setRegisterEvent:(BOOL)enable {
    objc_setAssociatedObject(self, @selector(registerEvent), @(enable), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)removeRegisterEvents {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    UILabel *label = objc_getAssociatedObject(self, @selector(placeholderLabel));
    if (label && self.registerEvent) {
        for (NSString *key in self.class.observingKeys) {
            NSLog(@"removing key:%@", key);
            @try {
                [self removeObserver:self forKeyPath:key];
            }
            @catch (NSException *exception) {
#ifdef DEBUG
                NSLog(@"removeObserver exception:%@", exception);
#endif
            }
        }
        // remove label, make sure it will recreate if adding to other valid superview.
        objc_setAssociatedObject(self, @selector(placeholderLabel), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)registerEvents {
    // only register events when the place holder created
    UILabel *label = objc_getAssociatedObject(self, @selector(placeholderLabel));
    if (label && !self.registerEvent) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updatePlaceholderLabelFromNotification)
                                                     name:UITextViewTextDidChangeNotification
                                                   object:self];
        
        for (NSString *key in self.class.observingKeys) {
            [self addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:nil];
        }
        self.registerEvent = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"font"]) {
        self.needsUpdateFont = (change[NSKeyValueChangeNewKey] != nil);
    }
    [self updatePlaceholderLabel];
}


- (void)updatePlaceholderLabelFromNotification {
    NSLog(@"updatePlaceholderLabelFromNotification");
    [self updatePlaceholderLabel];
}

#pragma mark - Update
- (void)updatePlaceholderLabel {
    if (self.text.length) {
        [self.placeholderLabel removeFromSuperview];
        return;
    }
    
    [self insertSubview:self.placeholderLabel atIndex:0];
    
    if (self.needsUpdateFont) {
        self.placeholderLabel.font = self.font;
        self.needsUpdateFont = NO;
    }
    self.placeholderLabel.textAlignment = self.textAlignment;
    
    // `NSTextContainer` is available since iOS 7
    CGFloat lineFragmentPadding;
    UIEdgeInsets textContainerInset;
    
#pragma deploymate push "ignored-api-availability"
    // iOS 7+
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        lineFragmentPadding = self.textContainer.lineFragmentPadding;
        textContainerInset = self.textContainerInset;
    }
#pragma deploymate pop
    
    // iOS 6
    else {
        lineFragmentPadding = 5;
        textContainerInset = UIEdgeInsetsMake(8, 0, 8, 0);
    }
    
    CGFloat x = lineFragmentPadding + textContainerInset.left;
    CGFloat y = textContainerInset.top;
    CGFloat width = CGRectGetWidth(self.bounds) - x - lineFragmentPadding - textContainerInset.right;
    CGFloat height = [self.placeholderLabel sizeThatFits:CGSizeMake(width, 0)].height;
    self.placeholderLabel.frame = CGRectMake(x, y, width, height);
}

@end
