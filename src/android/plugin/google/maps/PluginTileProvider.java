package plugin.google.maps;

import com.google.android.gms.maps.model.UrlTileProvider;

import java.net.MalformedURLException;
import java.net.URL;

import android.util.Log;

public class PluginTileProvider extends UrlTileProvider {

  private String baseUrl;

  public PluginTileProvider(int width, int height, String url) {
      super(width, height);
      this.baseUrl = url;
  }

  @Override
  public URL getTileUrl(int x, int y, int zoom) {
      //Log.w("GoogleMap", "Tile " + x + "," + y + ","+zoom + ": "+baseUrl.replace("<zoom>", ""+zoom).replace("<x>",""+x).replace("<y>",""+y));
      try {
          return new URL(baseUrl.replace("<zoom>", ""+zoom).replace("<x>",""+x).replace("<y>",""+y));
      } catch (MalformedURLException e) {
          e.printStackTrace();
      }
      return null;
  }
}
