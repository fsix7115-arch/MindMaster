package com.mindmaster.app;

import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * Keeps navigation inside the local app. Anything that is not
 * a file:// asset URL is redirected back to the home page —
 * the app never opens an external browser or network URL.
 */
public class MindMasterWebViewClient extends WebViewClient {

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
        if (url != null && url.startsWith("file://")) {
            return false; // let the WebView load local assets
        }
        view.loadUrl("file:///android_asset/web/index.html");
        return true;
    }
}
