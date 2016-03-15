package plugin.google.maps;

import android.util.Log;

import java.util.ArrayList;
import java.util.List;

import org.apache.cordova.CallbackContext;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.graphics.Color;
import android.text.TextUtils;

import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.LatLngBounds;
import com.google.android.gms.maps.model.Polyline;
import com.google.android.gms.maps.model.PolylineOptions;

public class PluginPolyline extends MyPlugin implements MyPluginInterface  {

  private static List<LatLng> decodePoly(String encryptedPath) {
    int encryptedPathLength = encryptedPath.length();
    int chunkSize = 5;
    int numChunks = (int) Math.ceil(encryptedPathLength/chunkSize) + 1;
    int curChunk = 0;
    int pos = encryptedPathLength;
    int start;
    String chunk;
    String[] chunks = new String[numChunks];
    while (pos >= 0) {
      start = Math.max(pos-chunkSize, 0);
      chunk = encryptedPath.substring(start, pos);
      chunks[curChunk] = chunk;
      pos -= chunkSize;
      curChunk += 1;
    }
    String encodedPath = TextUtils.join("", chunks);

    List<LatLng> poly = new ArrayList<LatLng>();

    try {
      int index = 0, len = encodedPath.length();
      int lat = 0, lng = 0;

      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          b = encodedPath.charAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encodedPath.charAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        LatLng p = new LatLng(((double) lat / (double) 1E5), ((double) lng / (double) 1E5));
        poly.add(p);
        //poly.add(((double) lat / (double) 1E5));
        //poly.add(((double) lng / (double) 1E5));
      }
    }
    catch (Exception e) {
      Log.w("GoogleMaps", "decodePoly error");
    }

    return poly;
  }

  private JSONObject buildPolyline(final JSONObject opts) throws JSONException {
    JSONObject result = new JSONObject();

    final PolylineOptions polylineOptions = new PolylineOptions();
    int color;
    LatLngBounds.Builder builder = new LatLngBounds.Builder();

    String encryptedPath;
    if (opts.has("encodedPath")) {
      encryptedPath = opts.getString("encodedPath");
    }
    else {
      encryptedPath = "";
    }

    //result.put("encryptedPath", encryptedPath);
    if (encryptedPath.length() > 0) {
        List<LatLng> path = decodePoly(encryptedPath);
        int i = 0;
        for (i = 0; i < path.size(); i++) {
          polylineOptions.add(path.get(i));
          builder.include(path.get(i));
        }
    }
    else if (opts.has("points")) {
      JSONArray points = opts.getJSONArray("points");
      List<LatLng> path = PluginUtil.JSONArray2LatLngList(points);
      int i = 0;
      for (i = 0; i < path.size(); i++) {
        polylineOptions.add(path.get(i));
        builder.include(path.get(i));
      }
    }
    if (opts.has("color")) {
      color = PluginUtil.parsePluginColor(opts.getJSONArray("color"));
      polylineOptions.color(color);
    }
    if (opts.has("width")) {
      polylineOptions.width(opts.getInt("width") * this.density);
    }
    if (opts.has("visible")) {
      polylineOptions.visible(opts.getBoolean("visible"));
    }
    if (opts.has("geodesic")) {
      polylineOptions.geodesic(opts.getBoolean("geodesic"));
    }
    if (opts.has("zIndex")) {
      polylineOptions.zIndex(opts.getInt("zIndex"));
    }
    
    Polyline polyline = map.addPolyline(polylineOptions);
    String id = "polyline_" + polyline.getId();
    this.objects.put(id, polyline);

    String boundsId = "polyline_bounds_" + polyline.getId();
    this.objects.put(boundsId, builder.build());

    result.put("hashCode", polyline.hashCode());
    result.put("id", id);

    if (opts.has("tappable") && opts.getBoolean("tappable")) {
      this.tappables.put(id, true);
    }

    return result;
  }

  /**
   * Create polyline
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void createPolyline(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    JSONObject opts = args.getJSONObject(1);
    JSONObject result = this.buildPolyline(opts);
    callbackContext.success(result);
  }

  /**
   * Create polylines
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void createPolylines(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    //Log.w("GoogleMaps", "createPolylines");

    JSONArray polylinesOptionsArray = args.getJSONArray(1);

    JSONArray polylines = new JSONArray();
    JSONObject opts;
    JSONObject result;
    int i;
    for (i = 0; i < polylinesOptionsArray.length(); i++) {
      opts = polylinesOptionsArray.getJSONObject(i);
      result = this.buildPolyline(opts);
      polylines.put(result);
    }
    callbackContext.success(polylines);
  }

  /**
   * Decode encoded paths
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void decodePath(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String encryptedPath = args.getString(1);

    JSONArray points = new JSONArray();
    JSONObject point;
    LatLng latlng;
    List<LatLng> path = decodePoly(encryptedPath);
    int i = 0;
    for (i = 0; i < path.size(); i++) {
      point = new JSONObject();
      latlng = path.get(i);
      point.put("lat", Double.valueOf(latlng.latitude));
      point.put("lng", Double.valueOf(latlng.longitude));
      points.put(point);
    }
    callbackContext.success(points);
  }

  /**
   * Draw geodesic line
   * @ref http://jamesmccaffrey.wordpress.com/2011/04/17/drawing-a-geodesic-line-for-bing-maps-ajax/
   * @ref http://spphire9.wordpress.com/2014/02/11/%E4%BA%8C%E6%AC%A1%E3%83%99%E3%82%B8%E3%82%A7%E6%9B%B2%E7%B7%9A%E3%81%A8%E7%B7%9A%E5%88%86%E3%81%AE%E5%BD%93%E3%81%9F%E3%82%8A%E5%88%A4%E5%AE%9A/
   * @ref http://my-clip-devdiary.blogspot.com/2014/01/html5canvas.html
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void createPolyline2(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    final PolylineOptions polylineOptions = new PolylineOptions();
    int color;
    
    JSONObject opts = args.getJSONObject(1);
    if (opts.has("points")) {
      JSONArray points = opts.getJSONArray("points");
      List<LatLng> path = PluginUtil.JSONArray2LatLngList(points);
      
      for (int k = 0; k < path.size() - 1; k++) {
        LatLng start = path.get(k);
        LatLng finish = path.get(k + 1);
        
        if (start.longitude > finish.longitude) {
          start = finish;
          finish = path.get(k);
        }
        
        // convert to radians
        double lat1 = start.latitude * (Math.PI / 180.0);
        double lng1 = start.longitude * (Math.PI / 180.0);
        double lat2 = finish.latitude * (Math.PI / 180.0);
        double lng2 = finish.longitude * (Math.PI / 180.0);
        
        double d = 2 * Math.asin(Math.sqrt(Math.pow((Math.sin((lat1 - lat2) / 2)), 2) +
            Math.cos(lat1) * Math.cos(lat2) * Math.pow((Math.sin((lng1 - lng2) / 2)), 2)));
        List<LatLng> wayPoints = new ArrayList<LatLng>();
        double f = 0.00000000f; // fraction of the curve
        double finc = 0.01000000f; // fraction increment
        
        while (f <= 1.00000000f) {
          double A = Math.sin((1.0 - f) * d) / Math.sin(d);
          double B = Math.sin(f * d) / Math.sin(d);
  
          double x = A * Math.cos(lat1) * Math.cos(lng1) + B * Math.cos(lat2) * Math.cos(lng2);
          double y = A * Math.cos(lat1) * Math.sin(lng1) + B * Math.cos(lat2) * Math.sin(lng2);
          double z = A * Math.sin(lat1) + B * Math.sin(lat2);
          double lat = Math.atan2(z, Math.sqrt((x*x) + (y*y)));
          double lng = Math.atan2(y, x);
  
          LatLng wp = new LatLng(lat / (Math.PI / 180.0), lng / ( Math.PI / 180.0));
          wayPoints.add(wp);
          
          f += finc;
        } // while
  
        // break into waypoints with negative longitudes and those with positive longitudes
        List<LatLng> negLons = new ArrayList<LatLng>(); // lat-lons where the lon part is negative
        List<LatLng> posLons = new ArrayList<LatLng>();
        List<LatLng> connect = new ArrayList<LatLng>();
  
        for (int i = 0; i < wayPoints.size(); ++i) {
          if (wayPoints.get(i).longitude <= 0.0f)
            negLons.add(wayPoints.get(i));
          else
            posLons.add(wayPoints.get(i));
        }
        
        // we may have to connect over 0.0 longitude
        for (int i = 0; i < wayPoints.size() - 1; ++i) {
          if (wayPoints.get(i).longitude <= 0.0f && wayPoints.get(i+1).longitude >= 0.0f ||
              wayPoints.get(i).longitude >= 0.0f && wayPoints.get(i+1).longitude <= 0.0f) {
            if (Math.abs(wayPoints.get(i).longitude) + Math.abs(wayPoints.get(i+1).longitude) < 100.0f) {
              connect.add(wayPoints.get(i));
              connect.add(wayPoints.get(i+1));
            }
          }
        }

        PolylineOptions options = new PolylineOptions();
        options.color(Color.RED);
        options.width(4);
        if (negLons.size() >= 2) {
          options.addAll(negLons);
        }
  
        if (posLons.size() >= 2) {
          options.addAll(posLons);
        }
  
        if (connect.size() >= 2) {
          options.addAll(connect);
        }
        map.addPolyline(options);
      }
    }

    this.sendNoResult(callbackContext);
  }
  
  /**
   * set color
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void setColor(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String id = args.getString(1);
    int color = PluginUtil.parsePluginColor(args.getJSONArray(2));
    this.setInt("setColor", id, color, callbackContext);
  }
  
  /**
   * set width
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void setWidth(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String id = args.getString(1);
    float width = (float) args.getDouble(2) * this.density;
    this.setFloat("setWidth", id, width, callbackContext);
  }
  
  /**
   * set z-index
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void setZIndex(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String id = args.getString(1);
    float zIndex = (float) args.getDouble(2);
    this.setFloat("setZIndex", id, zIndex, callbackContext);
  }
  

  /**
   * Remove the polyline
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void remove(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String id = args.getString(1);
    Polyline polyline = this.getPolyline(id);
    if (polyline == null) {
      this.sendNoResult(callbackContext);
      return;
    }
    this.objects.remove(id);
    this.tappables.remove(id);

    id = "polyline_bounds_" + polyline.getId();
    this.objects.remove(id);
    
    polyline.remove();
    this.sendNoResult(callbackContext);
  }
  /**
   * Set points
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void setPoints(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String id = args.getString(1);
    Polyline polyline = this.getPolyline(id);
    
    JSONArray points = args.getJSONArray(2);
    List<LatLng> path = PluginUtil.JSONArray2LatLngList(points);
    polyline.setPoints(path);

    LatLngBounds.Builder builder = new LatLngBounds.Builder();
    for (int i = 0; i < path.size(); i++) {
      builder.include(path.get(i));
    }
    this.objects.put("polyline_bounds_" + polyline.getId(), builder.build());

    this.sendNoResult(callbackContext);
  }
  /**
   * set geodesic
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void setGeodesic(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String id = args.getString(1);
    boolean isGeodisic = args.getBoolean(2);
    this.setBoolean("setGeodesic", id, isGeodisic, callbackContext);
  }

  /**
   * Set visibility for the object
   * @param args
   * @param callbackContext
   * @throws JSONException
   */
  @SuppressWarnings("unused")
  private void setVisible(JSONArray args, CallbackContext callbackContext) throws JSONException {
    boolean visible = args.getBoolean(2);
    String id = args.getString(1);
    this.setBoolean("setVisible", id, visible, callbackContext);
  }
}
