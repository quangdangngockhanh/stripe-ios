//
//  StripeError.m
//  Stripe
//
//  Created by Saikat Chakrabarti on 11/4/12.
//
//

#import "StripeError.h"

#import "STPFormEncoder.h"
#import "STPLocalizationUtils.h"

NSString *const StripeDomain = @"com.stripe.lib";
NSString *const STPCardErrorCodeKey = @"com.stripe.lib:CardErrorCodeKey";
NSString *const STPErrorMessageKey = @"com.stripe.lib:ErrorMessageKey";
NSString *const STPErrorParameterKey = @"com.stripe.lib:ErrorParameterKey";
NSString *const STPInvalidNumber = @"com.stripe.lib:InvalidNumber";
NSString *const STPInvalidExpMonth = @"com.stripe.lib:InvalidExpiryMonth";
NSString *const STPInvalidExpYear = @"com.stripe.lib:InvalidExpiryYear";
NSString *const STPInvalidCVC = @"com.stripe.lib:InvalidCVC";
NSString *const STPIncorrectNumber = @"com.stripe.lib:IncorrectNumber";
NSString *const STPExpiredCard = @"com.stripe.lib:ExpiredCard";
NSString *const STPCardDeclined = @"com.stripe.lib:CardDeclined";
NSString *const STPProcessingError = @"com.stripe.lib:ProcessingError";
NSString *const STPIncorrectCVC = @"com.stripe.lib:IncorrectCVC";
NSString *const STPPaymentMethodNotAvailable = @"com.stripe.lib:PaymentMethodNotAvailable";

@implementation NSError(Stripe)

+ (NSError *)stp_errorFromStripeResponse:(NSDictionary *)jsonDictionary {
    NSDictionary *errorDictionary = jsonDictionary[@"error"];
    if (!errorDictionary) {
        return nil;
    }
    NSString *type = errorDictionary[@"type"];
    NSString *devMessage = errorDictionary[@"message"];
    NSString *parameter = errorDictionary[@"param"];
    NSInteger code = 0;
    
    // There should always be a message and type for the error
    if (devMessage == nil || type == nil) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: [self stp_unexpectedErrorMessage],
                                   STPErrorMessageKey: @"Could not interpret the error response that was returned from Stripe."
                                   };
        return [[self alloc] initWithDomain:StripeDomain code:STPAPIError userInfo:userInfo];
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[STPErrorMessageKey] = devMessage;
    
    if (parameter) {
        userInfo[STPErrorParameterKey] = [STPFormEncoder stringByReplacingSnakeCaseWithCamelCase:parameter];
    }
    
    if ([type isEqualToString:@"api_error"]) {
        code = STPAPIError;
        userInfo[NSLocalizedDescriptionKey] = [self stp_unexpectedErrorMessage];
    } else if ([type isEqualToString:@"invalid_request_error"]) {
        code = STPInvalidRequestError;
        userInfo[NSLocalizedDescriptionKey] = devMessage;
    } else if ([type isEqualToString:@"card_error"]) {
        code = STPCardError;
        NSDictionary *errorCodes = @{
                                     @"incorrect_number": @{@"code": STPIncorrectNumber, @"message": [self stp_cardErrorInvalidNumberUserMessage]},
                                     @"invalid_number": @{@"code": STPInvalidNumber, @"message": [self stp_cardErrorInvalidNumberUserMessage]},
                                     @"invalid_expiry_month": @{@"code": STPInvalidExpMonth, @"message": [self stp_cardErrorInvalidExpMonthUserMessage]},
                                     @"invalid_expiry_year": @{@"code": STPInvalidExpYear, @"message": [self stp_cardErrorInvalidExpYearUserMessage]},
                                     @"invalid_cvc": @{@"code": STPInvalidCVC, @"message": [self stp_cardInvalidCVCUserMessage]},
                                     @"expired_card": @{@"code": STPExpiredCard, @"message": [self stp_cardErrorExpiredCardUserMessage]},
                                     @"incorrect_cvc": @{@"code": STPIncorrectCVC, @"message": [self stp_cardInvalidCVCUserMessage]},
                                     @"card_declined": @{@"code": STPCardDeclined, @"message": [self stp_cardErrorDeclinedUserMessage]},
                                     @"processing_error": @{@"code": STPProcessingError, @"message": [self stp_cardErrorProcessingErrorUserMessage]},
                                     @"payment_method_not_available": @{@"code": STPPaymentMethodNotAvailable, @"message": [self stp_cardErrorPaymentMethodNotAvailableUserMessage]},
                                     };
        NSDictionary *codeMapEntry = errorCodes[errorDictionary[@"code"]];
        
        if (codeMapEntry) {
            userInfo[STPCardErrorCodeKey] = codeMapEntry[@"code"];
            userInfo[NSLocalizedDescriptionKey] = codeMapEntry[@"message"];
        } else {
            userInfo[STPCardErrorCodeKey] = errorDictionary[@"code"];
            userInfo[NSLocalizedDescriptionKey] = devMessage;
        }
    }
    
    return [[self alloc] initWithDomain:StripeDomain code:code userInfo:userInfo];
}

+ (nonnull NSError *)stp_genericFailedToParseResponseError {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: [self stp_unexpectedErrorMessage],
                               STPErrorMessageKey: @"The response from Stripe failed to get parsed into valid JSON."
                               };
    return [[self alloc] initWithDomain:StripeDomain code:STPAPIError userInfo:userInfo];
}

+ (nonnull NSError *)stp_genericConnectionError {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: [self stp_unexpectedErrorMessage],
                               STPErrorMessageKey: @"There was an error connecting to Stripe."
                               };
    return [[self alloc] initWithDomain:StripeDomain code:STPConnectionError userInfo:userInfo];
}

- (BOOL)stp_isURLSessionCancellationError {
    return [self.domain isEqualToString:NSURLErrorDomain] && self.code == NSURLErrorCancelled;
}

#pragma mark Strings

+ (nonnull NSString *)stp_cardErrorInvalidNumberUserMessage {
    return STPLocalizedString(@"Your card's number is invalid", @"Error when the card number is not valid");
}

+ (nonnull NSString *)stp_cardInvalidCVCUserMessage {
    return STPLocalizedString(@"Your card's security code is invalid", @"Error when the card's CVC is not valid");
}

+ (nonnull NSString *)stp_cardErrorInvalidExpMonthUserMessage {
    return STPLocalizedString(@"Your card's expiration month is invalid", @"Error when the card's expiration month is not valid");
}

+ (nonnull NSString *)stp_cardErrorInvalidExpYearUserMessage {
    return STPLocalizedString(@"Your card's expiration year is invalid", @"Error when the card's expiration year is not valid");
}

+ (nonnull NSString *)stp_cardErrorExpiredCardUserMessage {
    return STPLocalizedString(@"Your card has expired", @"Error when the card has already expired");
}

+ (nonnull NSString *)stp_cardErrorDeclinedUserMessage {
    return STPLocalizedString(@"Your card was declined", @"Error when the card was declined by the card networks");
}

+ (nonnull NSString *)stp_unexpectedErrorMessage {
    return STPLocalizedString(@"There was an unexpected error -- try again in a few seconds", @"Unexpected error, such as a 500 from Stripe or a JSON parse error");
}

+ (nonnull NSString *)stp_cardErrorProcessingErrorUserMessage {
    return STPLocalizedString(@"There was an error processing your card -- try again in a few seconds", @"Error when there is a problem processing the card");
}

+ (nonnull NSString *)stp_cardErrorPaymentMethodNotAvailableUserMessage {
    return STPLocalizedString(@"The selected payment method is not available.", @"Error when the seleted payment method is not available (eg attempted to use 3D Secure on a card that does not support it).");
}

@end
