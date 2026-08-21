package au.com.zenithpayments.zenpay_example_app

import android.os.Bundle
import com.google.firebase.appdistribution.FirebaseAppDistribution
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!BuildConfig.DEBUG) {
            FirebaseAppDistribution.getInstance().updateIfNewReleaseAvailable()
        }
    }
}
