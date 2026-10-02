package com.mindmaster.app;

import android.graphics.Bitmap;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * Keeps navigation inside the local app.
 *
 * file:// URLs load normally (our own game pages).
 * Anything else is redirected to the app home — the app
 * never opens an external browser, and since the manifest
 * declares no INTERNET permission, network loads fail
 * closed by construction.
 */
public class MindMasterWebViewClient extends WebViewClient {

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
        if (request == null || request.getUrl() == null) return true;
        String url = request.getUrl().toString();
        if (url.startsWith("file://")) return false;
        view.loadUrl("file:///android_asset/web/index.html");
        return true;
    }

    @Override
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
        if (url != null && url.startsWith("file://")) return false;
        view.loadUrl("file:///android_asset/web/index.html");
        return true;
    }

    @Override
    public void onPageStarted(WebView view, String url, Bitmap favicon) {
        // Page load started — progress bar handled by WebChromeClient.
    }

    @Override
    public void onPageFinished(WebView view, String url) {
        // Page loaded — hide progress via onProgressChanged(100).
    }

    @Override
    public void onReceivedError(WebView view, int errorCode,
                                String description, String failingUrl) {
        // Offline or asset error: land on the home page.
        if (failingUrl != null && !failingUrl.endsWith("index.html")) {
            view.loadUrl("file:///android_asset/web/index.html");
        }
    }
}
