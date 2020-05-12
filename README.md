## google-purchases

Easiest way to retrieve info about google product or subscription purchase.

With config file it could be as simple as

```shell
$ ./google-purchases.sh products.get -t %yourProductPruchaseToken%
```
or
```shell
./google-purchases.sh subscriptions.get -t %yourSubscriptionPurchaseToken%
```

Handy tool for testing and debugging using Google Play Developer API
v3 for Purchases.



### Usage

```shell
./google-purchases.sh %command% [-options]
```

Options:

* `-t %purchaseToken%` mandatory
* `-c %configLocation%` optional, default config location is` $HOME/.google-purchases.conf`
* `-s %productId%` optional, iap or subscription product id associated with purchase token. Can be avoided with `product_ids` in config. 
* `-p %package%` optional if set in config
* `-a %accessToken%` optional if set 

To achieve the briefest form your should provide config file.


or specify config file location with -c option
```shell
./google-purchases.sh %command% -c %confFileLocation% -t %yourProductPurchaseToken%
```
 

#### Strongly advised config settings:
Config file is not mandatory but helps a lots. 
 
```
package=com.my-app-package
client_id=your_google_client_id
client_secret=your_google_client_secret
refresh_token=your_refresh_token
```
_client_id_, _client_secret_ and _refresh_token_ would be used 
to obtain Google's OAUTH 2.0 Access Token required at each request as authorization param.
 

As an alternative you can omit OAUTH-related settings and explicitly pass Access token at each invocation with `-a` option.
```
./google-purchases.sh subscriptions.get -a googleOAuthAccessToken -t yourSubscriptionPurchaseToken
```
Note that Access token is valid only for an hour after its creation.

`package` from config is used in every request. 
Use `-p %package%` cli option to override its value or simply make aliases for command with different configs provided.  



#### Additional config settings

The pain with Google API is not only with all that OAUTH params included into request, 
but with exact productId/subscriptionId which must be passed within each API request.

```
GET https://www.googleapis.com/androidpublisher/v3/applications/%packageName%/purchases/products/%productId%/tokens/%token%
```
Also in some cases it could be not obvious which product is associated with given purchase token.
E.g. you found some purchase token in error log or may be you are simply lazy and dont what search for productId and copy-paste it.

So here are additional config params
```
product_ids=your_product_id.1,your_product_id.2,your_product_id.3
subscription_ids=your_subscription_id.1,your_subscription_id.2
```


The biggest cons is in draining your daily Google Purchase API Request Quota.
 
Cause if you have 3 products set in `product_ids` config param and you token is associated with 3rd - then you are making 2 unnecessary calls.

So I don't advocate for additional settings usage, but you know.. it's convenient.

##### Output example
```shell
$ ./google-purchases.sh products.get -s your_product -t someProductPurchaseToken
Using default conf ~/.google-purchases.conf
Access token haven't been passed (-a option), trying to obtain it via OAUTH with credentials from "~/.google-purchases.conf" config
{
  "purchaseTimeMillis": "15679000000000",
  "purchaseState": 0,
  "consumptionState": 0,
  "developerPayload": "",
  "orderId": "GPA.1111-2222-3333-4444",
  "purchaseType": 0,
  "acknowledgementState": 0,
  "kind": "androidpublisher#productPurchase"
} 
```