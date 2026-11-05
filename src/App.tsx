import { useEffect, useRef, useState } from "react";
import maplibregl, { type Map as MapLibreMap } from "maplibre-gl";
import {
  Activity, ChevronDown, CircleHelp, Compass, Crosshair, FolderKanban,
  Layers3, Map as MapIcon, MapPinned, Menu, Minus, Plus, Ruler,
  Search, Settings2, Shapes, SlidersHorizontal, Sparkles
} from "lucide-react";
import { isSupabaseConfigured } from "./lib/supabase";

type Tool = "select" | "point" | "line" | "polygon" | "measure";

const tools: { id: Tool; label: string; icon: typeof MapIcon }[] = [
  { id: "select", label: "Select", icon: Crosshair },
  { id: "point", label: "Add point", icon: MapPinned },
  { id: "line", label: "Draw line", icon: Ruler },
  { id: "polygon", label: "Draw area", icon: Shapes },
  { id: "measure", label: "Measure", icon: Activity },
];

export default function App() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const [activeTool, setActiveTool] = useState<Tool>("select");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [mapReady, setMapReady] = useState(false);
  const [showLayers, setShowLayers] = useState(true);

  useEffect(() => {
    if (!mapContainer.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: mapContainer.current,
      center: [0, 20],
      zoom: 1.7,
      minZoom: 2,
      maxZoom: 19,
      attributionControl: false,
      style: {
        version: 8,
        sources: {
          osm: {
            type: "raster",
            tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
            tileSize: 256,
            attribution: "© OpenStreetMap contributors",
          },
        },
        layers: [{ id: "osm", type: "raster", source: "osm" }],
      },
    });

    map.addControl(new maplibregl.NavigationControl({ showCompass: true }), "bottom-right");
    map.addControl(new maplibregl.AttributionControl({ compact: true }), "bottom-left");
    map.on("load", () => setMapReady(true));
    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  const chooseTool = (tool: Tool) => setActiveTool(tool);

  return (
    <main className="app-shell">
      <header className="topbar">
        <button className="brand" onClick={() => setSidebarOpen(!sidebarOpen)} aria-label="Toggle sidebar">
          <span className="brand-mark"><MapIcon size={20} /></span>
          <span className="brand-name">map<span>draw</span><small>SPATIAL WORKSPACE</small></span>
        </button>
        <div className="workspace-select">
          <span className="workspace-kicker">WORKSPACE</span>
          <button className="workspace-button">Personal workspace <ChevronDown size={15} /></button>
        </div>
        <div className="topbar-actions">
          <span className={isSupabaseConfigured ? "connection connected" : "connection"}>
            <i />{isSupabaseConfigured ? "Backend configured" : "Preview mode"}
          </span>
          <button className="icon-button" title="Help"><CircleHelp size={18} /></button>
          <button className="avatar">JD</button>
        </div>
      </header>

      <div className="work-area">
        {sidebarOpen && <aside className="sidebar">
          <div className="sidebar-heading"><span>WORKSPACE</span><button className="icon-button small"><Plus size={16} /></button></div>
          <button className="nav-item active"><MapIcon size={17} /> Map canvas</button>
          <button className="nav-item"><FolderKanban size={17} /> Projects <span className="soon">SOON</span></button>
          <button className="nav-item"><Layers3 size={17} /> Data layers <span className="soon">SOON</span></button>
          <div className="sidebar-divider" />
          <div className="sidebar-heading"><span>MAP TOOLS</span><SlidersHorizontal size={15} /></div>
          <div className="tool-list">
            {tools.map(({ id, label, icon: Icon }) => (
              <button key={id} className={activeTool === id ? "tool-button selected" : "tool-button"} onClick={() => chooseTool(id)}>
                <Icon size={17} /><span>{label}</span>{id === "measure" && <span className="tool-tag">GIS</span>}
              </button>
            ))}
          </div>
          <div className="sidebar-note">
            <Sparkles size={16} />
            <div><strong>Your spatial workspace</strong><p>Organise locations, explore land and turn geographic data into decisions.</p></div>
          </div>
          <div className="sidebar-footer"><Settings2 size={16} /> Settings <span>0.1.0</span></div>
        </aside>}

        <section className="map-workspace">
          <div className="map-toolbar">
            <div className="map-title"><Compass size={17} /><div><strong>Untitled map</strong><span>Personal workspace / Map canvas</span></div></div>
            <div className="map-toolbar-actions">
              <div className="search-box"><Search size={16} /><input placeholder="Search places or coordinates" aria-label="Search places or coordinates" /></div>
              <button className="toolbar-button" onClick={() => setShowLayers(!showLayers)}><Layers3 size={16} /> Layers</button>
            </div>
          </div>
          <div className="map-stage">
            <div ref={mapContainer} className="map-canvas" />
            {!mapReady && <div className="map-loading"><div className="loader" /><span>Preparing your map…</span></div>}
            <div className="map-hint"><Crosshair size={14} /> {activeTool === "select" ? "Select a feature or explore the map" : activeTool === "measure" ? "Measurement tool selected — drawing workflow coming next" : `${tools.find(t => t.id === activeTool)?.label} tool selected — editing workflow coming next`}</div>
            {showLayers && <div className="layers-panel"><div className="panel-title"><span>MAP LAYERS</span><button className="icon-button small"><Plus size={15} /></button></div><div className="layer-row"><span className="layer-swatch base" /><span>OpenStreetMap</span><span className="layer-state">BASE</span></div><div className="layer-footnote">Additional project layers will appear here.</div></div>}
            <div className="map-coordinates">MAP DRAW <span>·</span> WGS84 <span>·</span> {mapReady ? "MAP READY" : "LOADING"}</div>
          </div>
          <footer className="statusbar"><span><i /> {mapReady ? "Map loaded" : "Loading map"}</span><span>EPSG:4326 · WGS 84</span><span>Map data © OpenStreetMap contributors</span></footer>
        </section>
      </div>
    </main>
  );
}
