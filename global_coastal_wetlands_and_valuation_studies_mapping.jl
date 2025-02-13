using Markdown
using InteractiveUtils
using Shapefile, GeoMakie, ColorSchemes, CairoMakie, GDAL, ArchGDAL, Makie, Distributions, DataFrames, Colors, GeoInterface, CSV, GeometryBasics

#ENV["DIVA_DATA"] = "your_path"

md"""
## Creating maps for the wetlands 
**upload the necessary files and preprocess them**
"""

wetlands = ArchGDAL.read("$(ENV["DIVA_DATA"])/graphs/global_wetland_clusters.gpkg")
floodplains = ArchGDAL.read("$(ENV["DIVA_DATA"])/graphs/Global_merit_coastplain_elecz_H100+2m_GADM1_partioned.gpkg")
coastlines = ArchGDAL.read("$(ENV["DIVA_DATA"])/graphs/Global_cls.gpkg")

wetlands_layer = ArchGDAL.getlayer(wetlands, "Global_wetland_clusters")
floodplains_layer = ArchGDAL.getlayer(floodplains, "Global_merit_coastplain_elecz_H100+2m_GADM1_partioned")
coastlines_layer = ArchGDAL.getlayer(coastlines, "Global_cls")

wetlands_features = ArchGDAL.collect(wetlands_layer)
floodplains_features = ArchGDAL.collect(floodplains_layer)
coastlines_features = ArchGDAL.collect(coastlines_layer)

# Standardizing wetland type names
for feature in wetlands_features
    if ArchGDAL.getfield(feature, 5) == "saltmarch"
        ArchGDAL.setfield!(feature, 5, "saltmarsh")
    end
    if ArchGDAL.getfield(feature, 5) == "saltmarsh"
        ArchGDAL.setfield!(feature, 5, "Saltmarsh")
    end
    if ArchGDAL.getfield(feature, 5) == "tidal flat"
        ArchGDAL.setfield!(feature, 5, "Tidal flat")    
    end
    if ArchGDAL.getfield(feature, 5) == "mangrove"
        ArchGDAL.setfield!(feature, 5, "Mangrove")
    end
end

# Remove coral reef features
filter!(wetlands_features) do feature
    ArchGDAL.getfield(feature, 5) != "coral reef"
end

wetlands_type = ArchGDAL.getfield.(wetlands_features, "type")
wetlands_geom = ArchGDAL.getgeom.(wetlands_features)
wetlands_lat = ArchGDAL.getfield.(wetlands_features, "latitude")
wetlands_lon = ArchGDAL.getfield.(wetlands_features, "longitude")
wetlands_area = ArchGDAL.getfield.(wetlands_features, "area")
floodplains_geom = ArchGDAL.getgeom.(floodplains_features)
coastlines_geom = ArchGDAL.getgeom.(coastlines_features)

md"""
### OpenStreetMap land and sea layers for higher resolution 
#### Extracting land and water geometries from shapefile
"""

water = ArchGDAL.read("$(ENV["DIVA_DATA"])/graphs/water_polygons.shp")
water_layer = ArchGDAL.getlayer(water, "water_polygons")
water_features = ArchGDAL.collect(water_layer)
water_geom = ArchGDAL.getgeom.(water_features)

land = ArchGDAL.read("$(ENV["DIVA_DATA"])/graphs/land_polygons.shp")
land_layer = ArchGDAL.getlayer(land, "land_polygons")
land_features = ArchGDAL.collect(land_layer)
land_geometry = ArchGDAL.getgeom.(land_features)

md"""
## The Wash, UK
"""
function create_thewash_map()
    # Creating colorblind-friendly color scheme using plasma
    n_color_types = 8  # adjust based on number of wetlands type
    plasma_colors = ColorSchemes.plasma[range(0, 1, length=n_color_types)]

    # Define wetland colors dictionary
    wetland_colors = Dict(
        "Saltmarsh" => plasma_colors[1],
        "Tidal flat" => plasma_colors[5],
        #"Mangrove" => plasma_colors[3]
		 "Floodplain" => plasma_colors[8] 
    )

    fig = Figure(size=(1000, 1200), backgroundcolor=:white) 
	
	#transparent background   
	#backgroundcolor=RGBA(1.0, 1.0, 1.0, 0.0)       

    ax = Axis(
        fig[1,1],
        title="Wetlands of The Wash Bay, UK",
        xlabel="Longitude (°E)",  # Added units
        ylabel="Latitude (°N)",   # Added units
        titlesize=20,
        xlabelsize=14,
        ylabelsize=14,
        xgridstyle=:dash,
        ygridstyle=:dash,
        xgridvisible=true,
        ygridvisible=true,
        xminorgridvisible=true,  # add gridlines
        yminorgridvisible=true,
        backgroundcolor=:white
    )

    # Definition of the viewport bounds
    xmin, xmax = -1.0, 1.5  # Original was -0.5, 1.0
    ymin, ymax = 52.5, 53.4  # Original was 52.7, 53.2

    # Create a clipping polygon using ArchGDAL
    wkt = "POLYGON(($xmin $ymin, $xmax $ymin, $xmax $ymax, $xmin $ymax, $xmin $ymin))"
    clip_polygon = ArchGDAL.fromWKT(wkt)

#### Add coastlines
lines!(ax, coastlines_geom, color=:gray, linewidth=1, linestyle=:solid)

	# Clip and add water geometry
    for geom in water_geom
        clipped_water = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_water)
            poly!(ax, clipped_water, color=RGB(0.3, 0.8, 1.0), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

    # Clip and add land geometry
    for geom in land_geometry
        clipped_land = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_land)
            poly!(ax, clipped_land, color=RGB(0.9, 0.9, 0.9), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

	# Add "Sea" text label
text!(ax, [1.0], [53.2],  # Adjust these coordinates to position the text where you want
      text="The North Sea",
      align=(:center, :center),
      fontsize=12,
      color=:gray, #darkblue
      font="DejaVu Sans Oblique")  #italics version of DejaVu Sans

    # Optimize floodplains rendering by clipping to viewport
    if @isdefined(floodplains_geom)
        clipped_geoms = [ArchGDAL.intersection(geom, clip_polygon) for geom in floodplains_geom]
        valid_geoms = filter(g -> !ArchGDAL.isempty(g), clipped_geoms)
        if !isempty(valid_geoms)
            #color=(:lightblue, 0.3)
            poly!(ax, valid_geoms, color=plasma_colors[8],
                  strokewidth=0.5, strokecolor=(:black, 0.2))  # Added subtle stroke
        end
    end

    # Setting viewport limits
    ax.aspect = DataAspect()
    xlims!(ax, xmin, xmax)    
    ylims!(ax, ymin, ymax)   

    # Add wetlands with enhanced styling
    if @isdefined(wetlands_geom)
        for (geom, type) in zip(wetlands_geom, wetlands_type)
            clipped_geom = ArchGDAL.intersection(geom, clip_polygon)
            if !ArchGDAL.isempty(clipped_geom)
                color = wetland_colors[type]
				#color = get(wetland_colors, type, plasma_colors[end])
                poly!(ax, clipped_geom, 
                      color=(color, 1.0),  #max opacity for better visibility
                      strokewidth=0.5,
                      strokecolor=(:black, 0.3))  # Added subtle stroke
            end
        end
    end

	
function draw_simple_compass(pos_x, pos_y, size)
    # Define a symmetric arrowhead
    arrow_width = size * 0.5  # Width of the arrowhead for emphasis

    # Left half of the arrowhead (black)
    left_arrow_points = [
        Point2f(pos_x, pos_y + size),                     # tip
        Point2f(pos_x - arrow_width / 2, pos_y),          # left base
        Point2f(pos_x, pos_y)                             # center base
    ]
    poly!(ax, left_arrow_points, color=:black)

    # Right half of the arrowhead (white)
    right_arrow_points = [
        Point2f(pos_x, pos_y + size),                     # tip
        Point2f(pos_x + arrow_width / 2, pos_y),          # right base
        Point2f(pos_x, pos_y)                             # center base
    ]
    poly!(ax, right_arrow_points, color=:white, strokecolor=:black, strokewidth=1)

    # Add "N" label
    text!(ax, [pos_x], [pos_y + size + 0.02],
          text=["N"],
          align=(:center, :bottom),
          fontsize=12,
          font="DejaVu Sans Bold")
end

# Add compass
compass_pos_x = xmin + 0.08  # Decrease to shift it left.
compass_pos_y = ymax - 0.20   # Increase to shift it upward.
compass_size = 0.1
draw_simple_compass(compass_pos_x, compass_pos_y, compass_size)


	
	# Add enhanced scale bar with alternating black/white sections
    function draw_scale_bar(start_x, start_y, total_length, n_sections)
        section_length = total_length / n_sections
        bar_height = 0.02  # Height of the scale bar
        
        # Draw sections
        for i in 0:(n_sections-1)
            x = start_x + i * section_length
            color = i % 2 == 0 ? :black : :white
            stroke_color = :black
            
            # Create rectangle for each section
            rect_points = [
                Point2f(x, start_y),
                Point2f(x + section_length, start_y),
                Point2f(x + section_length, start_y + bar_height),
                Point2f(x, start_y + bar_height)
            ]
            poly!(ax, rect_points, color=color, strokecolor=stroke_color, strokewidth=1)
        end
        
       # Add distance labels with "km" only on the first and last labels
for i in 0:n_sections
    x = start_x + i * section_length
    label = i == 0 || i == n_sections ? "$(i * 10) km" : "$(i * 10)"
    text!(ax, [x], [start_y - 0.02],
          text=[label],
          align=(:center, :top),
          fontsize=10,
          font="DejaVu Sans")
end

        # Add vertical end ticks
        for x in [start_x, start_x + total_length]
            lines!(ax, [x, x], [start_y - 0.01, start_y + bar_height + 0.01],
                  color=:black, linewidth=1)
        end
    end
    
    # Add scale bar
    scale_start_x = xmax - 0.6   # Increase to shift it to the right
    scale_start_y = ymin + 0.08  # Decrease to move it further down
    total_length = 0.4  # Total length of scale bar
    n_sections = 4     # Number of alternating sections
    draw_scale_bar(scale_start_x, scale_start_y, total_length, n_sections)


# Add cities 
cities = [
    ("King's Lynn", 0.4, 52.75),
    ("Boston", 0.0, 53.0),
    ("Skegness", 0.35, 53.15),
    ("Hunstanton", 0.5, 52.95)
]

for (city, lon, lat) in cities
    if xmin <= lon <= xmax && ymin <= lat <= ymax
        # Add city marker with white outline
        scatter!(ax, [lon], [lat], 
                color=:red, 
                markersize=13,
                strokewidth=1,
                strokecolor=:white)
#custom rules
		#align parameter: First value ==> :left, :center, or :right                   #Second value ==> :top, :center, or :bottom
		
		#offset parameter: First value ==> x offset (positive moves right, negative moves left, 0 to center)    
		#Second value ==> y offset (positive moves up, negative moves down, 0 center)
		
		
        # Customize text alignment for each city
        if city == "Hunstanton"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:right, :bottom),  # customize this
                  offset=(75, -20),            # customize this
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        elseif city == "King's Lynn"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:left, :top),      # customize this
                  offset=(5, -5),           # customize this
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        elseif city == "Boston"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:right, :center),  # customize this
                  offset=(-5, 0),           # customize this
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        elseif city == "Skegness"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:left, :bottom),   # customize this
                  offset=(-70, 5),            # customize this
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        end
    end
end
   
	
    # Add enhanced legend with title styling
    elements = [PolyElement(color=(c, 1.0), 
                          strokecolor=(:black, 0.3), 
                          strokewidth=0.5) for c in values(wetland_colors)]
    labels = collect(keys(wetland_colors))
    Legend(fig[1, 2],
           elements,
           labels,
           "Wetland Types",
           titlesize=16,
           titlefont="DejaVu Sans Bold",
           labelsize=12,
           padding=(10, 10, 10, 10),
           framevisible=true,
           backgroundcolor=(:white, 0.9))

    # Add source attribution
    text!(ax, [xmin + 0.1], [ymin + 0.05], 
          text=["DIVA modeling framework"], 
          align=(:left, :bottom),
          fontsize=8,
          color=(:black, 0.6))

    return fig
end

map_the_wash = create_thewash_map()

display(map_the_wash)
# Save
save("$(ENV["DIVA_DATA"])/graphs/svg/map_the_wash.svg", map_the_wash)

save("$(ENV["DIVA_DATA"])/graphs/pdf/map_the_wash.pdf", map_the_wash)

md"""
## Sundarbans map, Bangladesh
"""

function create_sundarbans_map()
    
    #color scheme using plasma
    n_color_types = 8  # adjust based on number of wetlands type
    plasma_colors = ColorSchemes.plasma[range(0, 1, length=n_color_types)]

    # Define wetland colors dictionary
    wetland_colors = Dict(
        "Mangrove" => plasma_colors[3],
       # "Tidal flat" => plasma_colors[5],
       # "Saltmarsh" => plasma_colors[1],
        "Floodplain" => plasma_colors[8] 
    )

    fig = Figure(size=(1000, 1200), backgroundcolor=:white) 
    
    #transparent background   
    #backgroundcolor=RGBA(1.0, 1.0, 1.0, 0.0)       

    ax = Axis(
        fig[1,1],
        title="Mangrove Forest of the Sundarbans, Bangladesh",
        xlabel="Longitude (°E)", 
        ylabel="Latitude (°N)",  
        titlesize=20,
        xlabelsize=14,
        ylabelsize=14,
        xgridstyle=:dash,
        ygridstyle=:dash,
        xgridvisible=true,
        ygridvisible=true,
        xminorgridvisible=true,  #gridlines
        yminorgridvisible=true,
        backgroundcolor=:white
    )

    # Defining viewport bounds for Sundarbans region
    xmin, xmax = 88.8, 89.8
    ymin, ymax = 21.6, 22.6

    # Creating a clipping polygon using ArchGDAL
    wkt = "POLYGON(($xmin $ymin, $xmax $ymin, $xmax $ymax, $xmin $ymax, $xmin $ymin))"
    clip_polygon = ArchGDAL.fromWKT(wkt)

    #### Add coastlines
    lines!(ax, coastlines_geom, color=:gray, linewidth=1, linestyle=:solid)

   # Clip and add water geometry
    for geom in water_geom
        clipped_water = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_water)
            poly!(ax, clipped_water, color=RGB(0.3, 0.8, 1.0), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

    # Clip and add land geometry
    for geom in land_geometry
        clipped_land = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_land)
            poly!(ax, clipped_land, color=RGB(0.9, 0.9, 0.9), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

    # Add "Sea" text label
    text!(ax, [89.25], [21.63],  # Adjusted coordinates for Bay of Bengal
          text="Bay of Bengal",
          align=(:center, :center),
          fontsize=12,
          color=:gray,
          font="DejaVu Sans Oblique")

    # Optimizing floodplains rendering by clipping to viewport
    if @isdefined(floodplains_geom)
        clipped_geoms = [ArchGDAL.intersection(geom, clip_polygon) for geom in floodplains_geom]
        valid_geoms = filter(g -> !ArchGDAL.isempty(g), clipped_geoms)
        if !isempty(valid_geoms)
            poly!(ax, valid_geoms, color=plasma_colors[8],
                  strokewidth=0.5, strokecolor=(:black, 0.2))
        end
    end

    # Setting viewport limits
    ax.aspect = DataAspect()
    xlims!(ax, xmin, xmax)    
    ylims!(ax, ymin, ymax)   

    # Adding wetlands
    if @isdefined(wetlands_geom)
        for (geom, type) in zip(wetlands_geom, wetlands_type)
            clipped_geom = ArchGDAL.intersection(geom, clip_polygon)
            if !ArchGDAL.isempty(clipped_geom)
                color = wetland_colors[type]
                poly!(ax, clipped_geom, 
                      color=(color, 1.0),
                      strokewidth=0.5,
                      strokecolor=(:black, 0.3))
            end
        end
    end

    function draw_simple_compass(pos_x, pos_y, size)
    #arrowhead
    arrow_width = size * 0.5  # width of the arrowhead 

    # Left half of the arrowhead (black)
    left_arrow_points = [
        Point2f(pos_x, pos_y + size),                     # tip
        Point2f(pos_x - arrow_width / 2, pos_y),          # left base
        Point2f(pos_x, pos_y)                             # center base
    ]
    poly!(ax, left_arrow_points, color=:black)

    # Right half of the arrowhead (white)
    right_arrow_points = [
        Point2f(pos_x, pos_y + size),                     # tip
        Point2f(pos_x + arrow_width / 2, pos_y),          # right base
        Point2f(pos_x, pos_y)                             # center base
    ]
    poly!(ax, right_arrow_points, color=:white, strokecolor=:black, strokewidth=1)

    # Add north "N" label
    text!(ax, [pos_x], [pos_y + size + 0.02],
          text=["N"],
          align=(:center, :bottom),
          fontsize=12,
          font="DejaVu Sans Bold")
end

# Add compass
compass_pos_x = xmin + 0.05  # Decrease to shift it left.
compass_pos_y = ymax - 0.15   # Increase to shift it upward.
compass_size = 0.06
draw_simple_compass(compass_pos_x, compass_pos_y, compass_size)


	
	# scale bar
    function draw_scale_bar(start_x, start_y, total_length, n_sections)
        section_length = total_length / n_sections
        bar_height = 0.015  # Height of the scale bar
        
        # draw sections
        for i in 0:(n_sections-1)
            x = start_x + i * section_length
            color = i % 2 == 0 ? :black : :white
            stroke_color = :black
            
            # creating rectangle for each section
            rect_points = [
                Point2f(x, start_y),
                Point2f(x + section_length, start_y),
                Point2f(x + section_length, start_y + bar_height),
                Point2f(x, start_y + bar_height)
            ]
            poly!(ax, rect_points, color=color, strokecolor=stroke_color, strokewidth=1)
        end
        
        # Add distance labels
        for i in 0:n_sections
            x = start_x + i * section_length
            text!(ax, [x], [start_y - 0.01],
                  text=["$(i * 5)km"],
                  align=(:center, :top),
                  fontsize=10,
                  font="DejaVu Sans")
        end
        
        # Add vertical end ticks
        for x in [start_x, start_x + total_length]
            lines!(ax, [x, x], [start_y - 0.005, start_y + bar_height + 0.005],
                  color=:black, linewidth=1)
        end
    end
    
    # Add enhanced scale bar
    scale_start_x = xmax - 0.25   # Increase to shift it to the right
    scale_start_y = ymin + 0.05  # Decrease to move it further down
    total_length = 0.20  # Total length of scale bar
    n_sections = 4     # Number of alternating sections
    draw_scale_bar(scale_start_x, scale_start_y, total_length, n_sections)

    # Add cities 
    cities = [
        ("Karamjal", 89.54, 22.45),
        ("Mongla", 89.6, 22.5),
        ("Katkata", 89.3, 22.3),
        ("Rampal", 89.66, 22.58)
    ]

    for (city, lon, lat) in cities
        if xmin <= lon <= xmax && ymin <= lat <= ymax
            scatter!(ax, [lon], [lat], 
                    color=:red, 
                    markersize=13,
                    strokewidth=1,
                    strokecolor=:white)

            # Customize text alignment for each city
            if city == "Karamjal"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :bottom),
                      offset=(25, -20),
                      fontsize=12,
                      color=:lightgray,
                      font="DejaVu Sans Bold")
            elseif city == "Mongla"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:left, :top),
                      offset=(5, -5),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Katkata"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :center),
                      offset=(-5, 0),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Rampal"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:left, :bottom),
                      offset=(-45, -20),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            end
        end
    end
   
    # Add legend
    elements = [PolyElement(color=(c, 1.0), 
                          strokecolor=(:black, 0.3), 
                          strokewidth=0.5) for c in values(wetland_colors)]
    labels = collect(keys(wetland_colors))
    Legend(fig[1, 2],
           elements,
           labels,
           "Wetland Types",
           titlesize=16,
           titlefont="DejaVu Sans Bold",
           labelsize=12,
           padding=(10, 10, 10, 10),
           framevisible=true,
           backgroundcolor=(:white, 0.9))

    # Add source attribution
    text!(ax, [xmin + 0.05], [ymin + 0.005], 
          text=["DIVA modeling framework"], 
          align=(:left, :bottom),
          fontsize=8,
          color=(:black, 0.6))

    return fig
end

map_sundarbans = create_sundarbans_map()

display(map_sundarbans)

# Save in both svg and pdf
save("$(ENV["DIVA_DATA"])/graphs/svg/map_sundarbans.svg", map_sundarbans)

save("$(ENV["DIVA_DATA"])/graphs/pdf/map_sundarbans.pdf", map_sundarbans)

md"""
## Florida map
"""

function create_florida_map()
    
    #colorblind-friendly color scheme with "plasma"
    n_color_types = 8  #number of wetlands type
    plasma_colors = ColorSchemes.plasma[range(0, 1, length=n_color_types)]

    # Define wetland colors dictionary
    wetland_colors = Dict(
        "Saltmarsh" => plasma_colors[1],
        "Mangrove" => plasma_colors[3],
       # "Tidal flat" => plasma_colors[5],
        "Floodplain" => plasma_colors[8] 
    )

    fig = Figure(size=(1000, 1200), backgroundcolor=:white) 
    
    #transparent background   
    #backgroundcolor=RGBA(1.0, 1.0, 1.0, 0.0)       

    ax = Axis(
        fig[1,1],
        title="Wetlands of South Florida",
        xlabel="Longitude (°W)",  
        ylabel="Latitude (°N)",   
        titlesize=20,
        xlabelsize=14,
        ylabelsize=14,
        xgridstyle=:dash,
        ygridstyle=:dash,
        xgridvisible=true,
        ygridvisible=true,
        xminorgridvisible=true,  #gridlines
        yminorgridvisible=true,
        backgroundcolor=:white
    )

    # Define bounds for South Florida region
    xmin, xmax = -82.0, -80.0  # Adjusted for Florida coordinates
    ymin, ymax = 25.0, 27.0    # Covers South Florida and Everglades

    # Creating a clipping polygon using ArchGDAL
    wkt = "POLYGON(($xmin $ymin, $xmax $ymin, $xmax $ymax, $xmin $ymax, $xmin $ymin))"
    clip_polygon = ArchGDAL.fromWKT(wkt)

    #### Add coastlines
    lines!(ax, coastlines_geom, color=:gray, linewidth=1, linestyle=:solid)

	  # Clipping and add water geometry
    for geom in water_geom
        clipped_water = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_water)
            poly!(ax, clipped_water, color=RGB(0.3, 0.8, 1.0), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

    # Clipping and add land geometry
    for geom in land_geometry
        clipped_land = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_land)
            poly!(ax, clipped_land, color=RGB(0.9, 0.9, 0.9), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end
  

    # Add water body labels
    text!(ax, [-81.7], [25.5],  
          text="Gulf of Mexico",
          align=(:center, :center),
          fontsize=12,
          color=:gray,
          font="DejaVu Sans Oblique")

    text!(ax, [-80.15], [25.2],  
          text="Atlantic Ocean",
          align=(:center, :center),
          fontsize=12,
          color=:gray,
          font="DejaVu Sans Oblique")

    # Optimizing floodplains rendering by clipping to viewport
    if @isdefined(floodplains_geom)
        clipped_geoms = [ArchGDAL.intersection(geom, clip_polygon) for geom in floodplains_geom]
        valid_geoms = filter(g -> !ArchGDAL.isempty(g), clipped_geoms)
        if !isempty(valid_geoms)
            poly!(ax, valid_geoms, color=plasma_colors[8],
                  strokewidth=0.5, strokecolor=(:black, 0.2))
        end
    end

    # Set viewport limits
    ax.aspect = DataAspect()
    xlims!(ax, xmin, xmax)    
    ylims!(ax, ymin, ymax)   

    # Add wetlands with enhanced styling
    if @isdefined(wetlands_geom)
        for (geom, type) in zip(wetlands_geom, wetlands_type)
            clipped_geom = ArchGDAL.intersection(geom, clip_polygon)
            if !ArchGDAL.isempty(clipped_geom)
                color = wetland_colors[type]
                poly!(ax, clipped_geom, 
                      color=(color, 1.0),
                      strokewidth=0.5,
                      strokecolor=(:black, 0.3))
            end
        end
    end

        function draw_simple_compass(pos_x, pos_y, size)
    #arrowhead
    arrow_width = size * 0.5  # Width of the arrowhead 

    # Left half of the arrowhead (black)
    left_arrow_points = [
        Point2f(pos_x, pos_y + size),                     # tip
        Point2f(pos_x - arrow_width / 2, pos_y),          # left base
        Point2f(pos_x, pos_y)                             # center base
    ]
    poly!(ax, left_arrow_points, color=:black)

    # Right half of the arrowhead (white)
    right_arrow_points = [
        Point2f(pos_x, pos_y + size),                     # tip
        Point2f(pos_x + arrow_width / 2, pos_y),          # right base
        Point2f(pos_x, pos_y)                             # center base
    ]
    poly!(ax, right_arrow_points, color=:white, strokecolor=:black, strokewidth=1)

    # Add "N" label
    text!(ax, [pos_x], [pos_y + size + 0.02],
          text=["N"],
          align=(:center, :bottom),
          fontsize=12,
          font="DejaVu Sans Bold")
end

# Add compass
compass_pos_x = xmin + 0.08  # Decrease to shift it left.
compass_pos_y = ymax - 0.20   # Increase to shift it upward.
compass_size = 0.1
draw_simple_compass(compass_pos_x, compass_pos_y, compass_size)


	
	#scale bar with alternating black/white sections
    function draw_scale_bar(start_x, start_y, total_length, n_sections)
        section_length = total_length / n_sections
        bar_height = 0.02  # Height of the scale bar
        
        #sections
        for i in 0:(n_sections-1)
            x = start_x + i * section_length
            color = i % 2 == 0 ? :black : :white
            stroke_color = :black
            
            #creating a rectangle for each section
            rect_points = [
                Point2f(x, start_y),
                Point2f(x + section_length, start_y),
                Point2f(x + section_length, start_y + bar_height),
                Point2f(x, start_y + bar_height)
            ]
            poly!(ax, rect_points, color=color, strokecolor=stroke_color, strokewidth=1)
        end

		# Add distance labels with "km" only on the first and last labels
for i in 0:n_sections
    x = start_x + i * section_length
    label = i == 0 || i == n_sections ? "$(i * 5) km" : "$(i * 5)"
    text!(ax, [x], [start_y - 0.01],
          text=[label],
          align=(:center, :top),
          fontsize=10,
          font="DejaVu Sans")
end

        
        # Add vertical end ticks
        for x in [start_x, start_x + total_length]
            lines!(ax, [x, x], [start_y - 0.005, start_y + bar_height + 0.005],
                  color=:black, linewidth=1)
        end
    end
    
    # Add enhanced scale bar
    scale_start_x = xmax - 0.35   # Increase to shift it to the right
    scale_start_y = ymin + 0.05  # Decrease to move it further down
    total_length = 0.3  # Total length of scale bar
    n_sections = 4     # Number of alternating sections
    draw_scale_bar(scale_start_x, scale_start_y, total_length, n_sections)

    # Add cities
    cities = [
        ("Miami", -80.19, 25.76),
        ("Naples", -81.80, 26.14),
        ("Fort Myers", -81.87, 26.64),
        ("Fort Lauderdale", -80.14, 26.12),
        ("Key Largo", -80.45, 25.08)
    ]

    for (city, lon, lat) in cities
        if xmin <= lon <= xmax && ymin <= lat <= ymax
            scatter!(ax, [lon], [lat], 
                    color=:red, 
                    markersize=13,
                    strokewidth=1,
                    strokecolor=:white)

            # Customize text alignment for each city
            if city == "Miami"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:left, :bottom),
                      offset=(-40, -20),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Naples"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :center),
                      offset=(-10, 0),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Fort Myers"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :top),
                      offset=(80, -5),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Fort Lauderdale"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:left, :center),
                      offset=(-120, 0),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Key Largo"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:left, :bottom),
                      offset=(20, 0),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            end
        end
    end
   
    # Add legend
    elements = [PolyElement(color=(c, 1.0), 
                          strokecolor=(:black, 0.3), 
                          strokewidth=0.5) for c in values(wetland_colors)]
    labels = collect(keys(wetland_colors))
    Legend(fig[1, 2],
           elements,
           labels,
           "Wetland Types",
           titlesize=16,
           titlefont="DejaVu Sans Bold",
           labelsize=12,
           padding=(10, 10, 10, 10),
           framevisible=true,
           backgroundcolor=(:white, 0.9))

    # Add source attribution
    text!(ax, [xmin + 0.2], [ymin + 0.1], 
          text=["DIVA modeling framework"], 
          align=(:left, :bottom),
          fontsize=8,
          color=(:black, 0.6))

    return fig
end

map_florida = create_florida_map()

display(map_florida)

# Save
save("$(ENV["DIVA_DATA"])/graphs/svg/map_florida.svg", map_florida)

save("$(ENV["DIVA_DATA"])/graphs/pdf/map_florida.pdf", map_florida)


md"""
## Wadden Sea
"""

function create_waddensea_map()
    
    # Create colorblind-friendly color scheme using plasma
    n_color_types = 8  # adjust based on number of wetlands type
    plasma_colors = ColorSchemes.plasma[range(0, 1, length=n_color_types)]

    # Define wetland colors dictionary
    wetland_colors = Dict(
        "Saltmarsh" => plasma_colors[1],
       # "Mangrove" => plasma_colors[3],
		"Tidal flat" => plasma_colors[5],
        "Floodplain" => plasma_colors[8] 
    )

    fig = Figure(size=(1000, 1200), backgroundcolor=:white) 
    
    ax = Axis(
        fig[1,1],
        title="Wetlands of the North Sea",
        xlabel="Longitude (°E)",  # Changed to E for Wadden Sea
        ylabel="Latitude (°N)",   
        titlesize=20,
        xlabelsize=14,
        ylabelsize=14,
        xgridstyle=:dash,
        ygridstyle=:dash,
        xgridvisible=true,
        ygridvisible=true,
        xminorgridvisible=true,
        yminorgridvisible=true,
        backgroundcolor=:white
    )

    # Define viewport bounds for Wadden Sea region
    xmin, xmax = 4.5, 9.5    # Extended xmax from 9.0 to 9.5
    ymin, ymax = 52.5, 55.5  # Covers Dutch-German-Danish Wadden Sea

    # Create a clipping polygon using ArchGDAL
    wkt = "POLYGON(($xmin $ymin, $xmax $ymin, $xmax $ymax, $xmin $ymax, $xmin $ymin))"
    clip_polygon = ArchGDAL.fromWKT(wkt)

    #### Add coastlines
    lines!(ax, coastlines_geom, color=:gray, linewidth=1, linestyle=:solid)

    # Clip and add water geometry
    for geom in water_geom
        clipped_water = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_water)
            poly!(ax, clipped_water, color=RGB(0.3, 0.8, 1.0), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

    # Clip and add land geometry
    for geom in land_geometry
        clipped_land = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_land)
            poly!(ax, clipped_land, color=RGB(0.9, 0.9, 0.9), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end
  
    # Add water body label
    text!(ax, [7.0], [54.5],  
          text="North Sea",
          align=(:center, :center),
          fontsize=12,
          color=:gray,
          font="DejaVu Sans Oblique")

    # Optimize floodplains rendering by clipping to viewport
    if @isdefined(floodplains_geom)
        clipped_geoms = [ArchGDAL.intersection(geom, clip_polygon) for geom in floodplains_geom]
        valid_geoms = filter(g -> !ArchGDAL.isempty(g), clipped_geoms)
        if !isempty(valid_geoms)
            poly!(ax, valid_geoms, color=plasma_colors[8],
                  strokewidth=0.5, strokecolor=(:black, 0.2))
        end
    end

    # Set viewport limits
    ax.aspect = DataAspect()
    xlims!(ax, xmin, xmax)    
    ylims!(ax, ymin, ymax)   

    # Add wetlands with enhanced styling
    if @isdefined(wetlands_geom)
        for (geom, type) in zip(wetlands_geom, wetlands_type)
            clipped_geom = ArchGDAL.intersection(geom, clip_polygon)
            if !ArchGDAL.isempty(clipped_geom)
                color = wetland_colors[type]
                poly!(ax, clipped_geom, 
                      color=(color, 1.0),
                      strokewidth=0.5,
                      strokecolor=(:black, 0.3))
            end
        end
    end

    # Compass function remains the same
    function draw_simple_compass(pos_x, pos_y, size)
        arrow_width = size * 0.5
        
        left_arrow_points = [
            Point2f(pos_x, pos_y + size),
            Point2f(pos_x - arrow_width / 2, pos_y),
            Point2f(pos_x, pos_y)
        ]
        poly!(ax, left_arrow_points, color=:black)

        right_arrow_points = [
            Point2f(pos_x, pos_y + size),
            Point2f(pos_x + arrow_width / 2, pos_y),
            Point2f(pos_x, pos_y)
        ]
        poly!(ax, right_arrow_points, color=:white, strokecolor=:black, strokewidth=1)

        text!(ax, [pos_x], [pos_y + size + 0.02],
              text=["N"],
              align=(:center, :bottom),
              fontsize=12,
              font="DejaVu Sans Bold")
    end

    # Add compass
    compass_pos_x = xmin + 0.25  # Adjusted for Wadden Sea map
    compass_pos_y = ymax - 0.5  
    compass_size = 0.25
    draw_simple_compass(compass_pos_x, compass_pos_y, compass_size)

    # Scale bar function remains the same
    function draw_scale_bar(start_x, start_y, total_length, n_sections)
        section_length = total_length / n_sections
        bar_height = 0.02
        
        for i in 0:(n_sections-1)
            x = start_x + i * section_length
            color = i % 2 == 0 ? :black : :white
            stroke_color = :black
            
            rect_points = [
                Point2f(x, start_y),
                Point2f(x + section_length, start_y),
                Point2f(x + section_length, start_y + bar_height),
                Point2f(x, start_y + bar_height)
            ]
            poly!(ax, rect_points, color=color, strokecolor=stroke_color, strokewidth=1)
        end

        for i in 0:n_sections
            x = start_x + i * section_length
            label = i == 0 || i == n_sections ? "$(i * 25) km" : "$(i * 25)"
            text!(ax, [x], [start_y - 0.01],
                  text=[label],
                  align=(:center, :top),
                  fontsize=10,
                  font="DejaVu Sans")
        end
        
        for x in [start_x, start_x + total_length]
            lines!(ax, [x, x], [start_y - 0.005, start_y + bar_height + 0.005],
                  color=:black, linewidth=1)
        end
    end
    
    # Add scale bar with adjusted position and scale
    scale_start_x = xmax - 1.1
    scale_start_y = ymin + 0.1
    total_length = 0.9
    n_sections = 4
    draw_scale_bar(scale_start_x, scale_start_y, total_length, n_sections)

    # Add major cities around Wadden Sea
    cities = [
        ("Bremen", 8.80, 53.08),
        ("Groningen", 6.57, 53.22),
        ("Wilhelmshaven", 8.10, 53.52),
        ("Esbjerg", 8.45, 55.47),
        ("Den Helder", 4.75, 52.96)
    ]

    for (city, lon, lat) in cities
        if xmin <= lon <= xmax && ymin <= lat <= ymax
            scatter!(ax, [lon], [lat], 
                    color=:red, 
                    markersize=13,
                    strokewidth=1,
                    strokecolor=:white)

# Customize text alignment for each city
        if city == "Bremen"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:right, :bottom),
                  offset=(-10, -10),
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        elseif city == "Groningen"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:right, :top),
                  offset=(28, 20),
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        elseif city == "Wilhelmshaven"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:right, :bottom),
                  offset=(-8, -10),
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        elseif city == "Esbjerg"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:right, :top),
                  offset=(-10, -2),
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        elseif city == "Den Helder"
            text!(ax, [lon], [lat], 
                  text=city,
                  align=(:right, :bottom),
                  offset=(43, -25),
                  fontsize=12,
                  color=:black,
                  font="DejaVu Sans Bold")
        end
    end
end
   
    # Add legend
    elements = [PolyElement(color=(c, 1.0), 
                          strokecolor=(:black, 0.3), 
                          strokewidth=0.5) for c in values(wetland_colors)]
    labels = collect(keys(wetland_colors))
    Legend(fig[1, 2],
           elements,
           labels,
           "Wetland Types",
           titlesize=16,
           titlefont="DejaVu Sans Bold",
           labelsize=12,
           padding=(10, 10, 10, 10),
           framevisible=true,
           backgroundcolor=(:white, 0.9))

   # Add source attribution
    text!(ax, [xmin + 0.2], [ymin + 0.1], 
          text=["DIVA modeling framework"], 
          align=(:left, :bottom),
          fontsize=8,
          color=(:black, 0.6))

	

    return fig
end

map_waddensea = create_waddensea_map()

display(map_waddensea)

# Save
save("$(ENV["DIVA_DATA"])/graphs/svg/map_waddensea.svg", map_waddensea)

save("$(ENV["DIVA_DATA"])/graphs/pdf/map_waddensea.pdf", map_waddensea)

md"""
## Camargue, France
"""

function create_camargue_map()
    
    # Create colorblind-friendly color scheme using plasma
    n_color_types = 8  # adjust based on number of wetlands type
    plasma_colors = ColorSchemes.plasma[range(0, 1, length=n_color_types)]

    # Define wetland colors dictionary
    wetland_colors = Dict(
        "Saltmarsh" => plasma_colors[3],
        "Tidal flat" => plasma_colors[5],
       # "Mangrove" => plasma_colors[1],
        "Floodplain" => plasma_colors[8] 
    )

    fig = Figure(size=(1000, 1200), backgroundcolor=:white) 
    
    ax = Axis(
        fig[1,1],
        title="Wetlands of the Camargue",
        xlabel="Longitude (°E)",  # Changed to E for France
        ylabel="Latitude (°N)",
        titlesize=20,
        xlabelsize=14,
        ylabelsize=14,
        xgridstyle=:dash,
        ygridstyle=:dash,
        xgridvisible=true,
        ygridvisible=true,
        xminorgridvisible=true,
        yminorgridvisible=true,
        backgroundcolor=:white
    )

    # Define viewport bounds for Camargue region - expanded for wider view
    xmin, xmax = 4.0, 5.1  # Widened from original 4.2, 4.9
    ymin, ymax = 43.2, 43.8  # Widened from original 43.3, 43.7

    # Create a clipping polygon using ArchGDAL
    wkt = "POLYGON(($xmin $ymin, $xmax $ymin, $xmax $ymax, $xmin $ymax, $xmin $ymin))"
    clip_polygon = ArchGDAL.fromWKT(wkt)

    #### Add coastlines
    lines!(ax, coastlines_geom, color=:gray, linewidth=1, linestyle=:solid)

    # Clip and add water geometry
    for geom in water_geom
        clipped_water = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_water)
            poly!(ax, clipped_water, color=RGB(0.3, 0.8, 1.0), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

    # Clip and add land geometry
    for geom in land_geometry
        clipped_land = ArchGDAL.intersection(geom, clip_polygon)
        if !ArchGDAL.isempty(clipped_land)
            poly!(ax, clipped_land, color=RGB(0.9, 0.9, 0.9), strokewidth=0.5, strokecolor=RGBA(0, 0, 0, 0.1))
        end
    end

    # Add water body labels
    text!(ax, [4.4], [43.3],  
          text="Mediterranean Sea",
          align=(:center, :center),
          fontsize=12,
          color=:gray,
          font="DejaVu Sans Oblique")

    # Optimize floodplains rendering by clipping to viewport
    if @isdefined(floodplains_geom)
        clipped_geoms = [ArchGDAL.intersection(geom, clip_polygon) for geom in floodplains_geom]
        valid_geoms = filter(g -> !ArchGDAL.isempty(g), clipped_geoms)
        if !isempty(valid_geoms)
            poly!(ax, valid_geoms, color=plasma_colors[8],
                  strokewidth=0.5, strokecolor=(:black, 0.2))
        end
    end

    # Set viewport limits
    ax.aspect = DataAspect()
    xlims!(ax, xmin, xmax)    
    ylims!(ax, ymin, ymax)   

    # Add wetlands with enhanced styling
    if @isdefined(wetlands_geom)
        for (geom, type) in zip(wetlands_geom, wetlands_type)
            clipped_geom = ArchGDAL.intersection(geom, clip_polygon)
            if !ArchGDAL.isempty(clipped_geom)
                color = wetland_colors[type]
                poly!(ax, clipped_geom, 
                      color=(color, 1.0),
                      strokewidth=0.5,
                      strokecolor=(:black, 0.3))
            end
        end
    end

    function draw_simple_compass(pos_x, pos_y, size)
        # Define a symmetric arrowhead
        arrow_width = size * 0.5  # Width of the arrowhead for emphasis

        # Left half of the arrowhead (black)
        left_arrow_points = [
            Point2f(pos_x, pos_y + size),
            Point2f(pos_x - arrow_width / 2, pos_y),
            Point2f(pos_x, pos_y)
        ]
        poly!(ax, left_arrow_points, color=:black)

        # Right half of the arrowhead (white)
        right_arrow_points = [
            Point2f(pos_x, pos_y + size),
            Point2f(pos_x + arrow_width / 2, pos_y),
            Point2f(pos_x, pos_y)
        ]
        poly!(ax, right_arrow_points, color=:white, strokecolor=:black, strokewidth=1)

        # Add "N" label
        text!(ax, [pos_x], [pos_y + size + 0.02],
              text=["N"],
              align=(:center, :bottom),
              fontsize=12,
              font="DejaVu Sans Bold")
    end

    # Add compass
    compass_pos_x = xmin + 0.05
    compass_pos_y = ymax - 0.12
    compass_size = 0.05
    draw_simple_compass(compass_pos_x, compass_pos_y, compass_size)

    # Add enhanced scale bar with alternating black/white sections
    function draw_scale_bar(start_x, start_y, total_length, n_sections)
        section_length = total_length / n_sections
        bar_height = 0.01
        
        # Draw sections
        for i in 0:(n_sections-1)
            x = start_x + i * section_length
            color = i % 2 == 0 ? :black : :white
            stroke_color = :black
            
            rect_points = [
                Point2f(x, start_y),
                Point2f(x + section_length, start_y),
                Point2f(x + section_length, start_y + bar_height),
                Point2f(x, start_y + bar_height)
            ]
            poly!(ax, rect_points, color=color, strokecolor=stroke_color, strokewidth=1)
        end

        # Add distance labels with "km" only on the first and last labels
        for i in 0:n_sections
            x = start_x + i * section_length
            label = i == 0 || i == n_sections ? "$(i * 2) km" : "$(i * 2)"  # Adjusted scale for Camargue
            text!(ax, [x], [start_y - 0.01],
                  text=[label],
                  align=(:center, :top),
                  fontsize=10,
                  font="DejaVu Sans")
        end
        
        # Add vertical end ticks
        for x in [start_x, start_x + total_length]
            lines!(ax, [x, x], [start_y - 0.005, start_y + bar_height + 0.005],
                  color=:black, linewidth=1)
        end
    end
    
    # Add enhanced scale bar
    scale_start_x = xmax - 0.18
    scale_start_y = ymin + 0.05
    total_length = 0.15  # Adjusted for Camargue scale
    n_sections = 4
    draw_scale_bar(scale_start_x, scale_start_y, total_length, n_sections)

    # Add cities with enhanced styling
    cities = [
        ("Arles", 4.63, 43.68),
        ("Saintes-Maries-de-la-Mer", 4.43, 43.45),
        ("Port-Saint-Louis-du-Rhône", 4.81, 43.38),
        ("Aigues-Mortes", 4.19, 43.57),
        ("Le Grau-du-Roi", 4.14, 43.54)
    ]

    for (city, lon, lat) in cities
        if xmin <= lon <= xmax && ymin <= lat <= ymax
            scatter!(ax, [lon], [lat], 
                    color=:red, 
                    markersize=13,
                    strokewidth=1,
                    strokecolor=:white)

            # Customize text alignment for each city
            if city == "Arles"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :bottom),
                      offset=(10, -18),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Saintes-Maries-de-la-Mer"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :top),
                      offset=(15, -5),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Port-Saint-Louis-du-Rhône"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :bottom),
                      offset=(75, -50),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Aigues-Mortes"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :center),
                      offset=(75, 15),
                      fontsize=12,
                      color=:black,
                      font="DejaVu Sans Bold")
            elseif city == "Le Grau-du-Roi"
                text!(ax, [lon], [lat], 
                      text=city,
                      align=(:right, :top),
                      offset=(8, -5),
                      fontsize=12,
                      color=:gray,
                      font="DejaVu Sans Bold")
            end
        end
    end
   
    # Add enhanced legend with title styling
    elements = [PolyElement(color=(c, 1.0), 
                          strokecolor=(:black, 0.3), 
                          strokewidth=0.5) for c in values(wetland_colors)]
    labels = collect(keys(wetland_colors))
    Legend(fig[1, 2],
           elements,
           labels,
           "Wetland Types",
           titlesize=16,
           titlefont="DejaVu Sans Bold",
           labelsize=12,
           padding=(10, 10, 10, 10),
           framevisible=true,
           backgroundcolor=(:white, 0.9))

    # Add source attribution
    text!(ax, [xmin + 0.05], [ymin + 0.02], 
          text=["DIVA modeling framework"], 
          align=(:left, :bottom),
          fontsize=8,
          color=(:black, 0.6))

    return fig
end

map_camargue = create_camargue_map()

display(map_camargue)

# Save
save("$(ENV["DIVA_DATA"])/graphs/svg/map_camargue.svg", map_camargue)

save("$(ENV["DIVA_DATA"])/graphs/pdf/map_camargue.pdf", map_camargue)

md"""
## let's plot the study sites according to their numbers of value
"""

wetland_values = CSV.read("$(ENV["DIVA_DATA"])/meta_regression_bt/wetland_values.csv", DataFrame)

# Group the data by location and count the points
location_counts = combine(groupby(wetland_values, [:Latitude, :Longitude]), nrow => :point_count)

#upload land and sea background from Nature Earth gpkg file
land_sea_background = ArchGDAL.read("$(ENV["DIVA_DATA"])/graphs/natural_earth_vector.gpkg")
sea_layer = ArchGDAL.getlayer(land_sea_background, "ne_10m_geography_marine_polys")
earth_layer = ArchGDAL.getlayer(land_sea_background, "ne_10m_geography_regions_polys")

#preprocessing
sea_features = ArchGDAL.collect(sea_layer)
earth_features = ArchGDAL.collect(earth_layer)

#geometries
sea_geom = ArchGDAL.getgeom.(sea_features)
earth_geom = ArchGDAL.getgeom.(earth_features)

longitude = location_counts.Longitude
latitude = location_counts.Latitude

point_count = location_counts.point_count
adj_point_count = log.(location_counts.point_count)

md"
### Create the map
"
studies_map2 = Figure(size = (1200, 900), fontsize = 14)

goa = GeoAxis(
    studies_map2[1, 1];
    title = "Global Distribution of Coastal Wetlands Local Valuation Studies",
    titlesize = 20,
    xlabel = "Longitude", 
    ylabel = "Latitude",
    xlabelsize = 12,
    ylabelsize = 12,
    dest = "+proj=wintri",  # Winkel tripel projection for better area preservation
	limits = ((-170, 170), (-75, 75))  # Limit the extent to focus on main landmasses
)

# Add coastlines with custom styling
lines!(goa, GeoMakie.coastlines(), color = :gray60)

# Define better visual parameters
min_size = 10
max_size = 70
scale_factor = (max_size - min_size) / sqrt(maximum(point_count))

# Improved marker size calculation with clamping
markersize = clamp.(
    min_size .+ scale_factor .* sqrt.(point_count),
    min_size,
    max_size
)

# Create a custom colormap with better contrast
colors = cgrad(:viridis, alpha=0.8)  # looks cool

# Add scatter plot with improved styling
scatter_points = scatter!(goa,
    longitude, 
    latitude, 
    color = adj_point_count, #point_count
    colormap = colors,
    markersize = markersize,
    strokewidth = 0.5,
    strokecolor = (:black, 0.3),
    alpha = 0.75
)

# Extract min and max log-transformed values from plotted data
vmin, vmax = extrema(adj_point_count)  

# Choose real-world tick values you want to display
real_ticks = [1, 50, 100, 150]  # Adjust based on your data range

# Convert real-world values to log-space positions
log_ticks = log.(real_ticks)

# Ensure ticks are within the plotted range
valid_idx = (log_ticks .>= vmin) .& (log_ticks .<= vmax)
filtered_ticks = log_ticks[valid_idx]  # Keep only ticks within range
filtered_labels = string.(real_ticks[valid_idx])  # Keep corresponding labels

Colorbar(studies_map2[1, 2],
    scatter_points,
    label = "Number of Valuations per Study Site",
    ticks = (filtered_ticks, filtered_labels),  # Log scale positions with real-value labels
    width = 15,
    labelsize = 12,
    ticklabelsize = 10
)

# Creating an empty space between map and annotation using a new row
studies_map2[2, 1:2] = Label(studies_map2, " ", fontsize = 1)

# Adjust layout
colsize!(studies_map2.layout, 1, Relative(0.9))
colsize!(studies_map2.layout, 2, Relative(0.1))

# Create a new row for the annotation text
Label(studies_map2[2, 1:2], 
    "Data source: ESVD",
    fontsize = 10,
    padding = (0, 0, 20, 0),  # top, right, bottom, left padding
    halign = :left
)

# Adjust the overall layout with better proportions
rowsize!(studies_map2.layout, 1, Relative(0.92))
rowsize!(studies_map2.layout, 2, Relative(0.08))  # Space between map and text

# Add annotations or text elements if needed
text!(goa,
    -200, -100,
    text = "Data source: ESVD",
    align = (:left, :bottom),
    fontsize = 10
)

studies_map2

# Save
save("$(ENV["DIVA_DATA"])/graphs/svg/studies_map2.svg", studies_map2)

save("$(ENV["DIVA_DATA"])/graphs/pdf/studies_map2.pdf", studies_map2)

md"""
## let's plot the study sites and the existing wetlands areas on the world map
"""

studies_wetlands_map = Figure(size = (1200, 900), fontsize = 14)

ga = GeoAxis(
    studies_wetlands_map[1, 1];
    title = "Global Distribution of Coastal Wetlands and Local Valuation Studies",
    titlesize = 20,
    xlabel = "Longitude", 
    ylabel = "Latitude",
    xlabelsize = 12,
    ylabelsize = 12,
    dest = "+proj=wintri",  # Winkel tripel projection for better area preservation
	limits = ((-170, 170), (-75, 75)) # Limit the extent to focus on main landmasses 
)

# Add coastlines 
lines!(ga, GeoMakie.coastlines(), color = :gray60)

 # Creating colorblind-friendly color scheme using plasma
    n_color_types = 8  # adjust based on number of wetlands type

   plasma_colors = ColorSchemes.plasma[range(0, 1, length=n_color_types)]

  # Define wetland colors dictionary
    wetland_colors = Dict(
        "Saltmarsh" => plasma_colors[1],
        "Tidal flat" => plasma_colors[7],
        "Mangrove" => plasma_colors[4]
		 #"Floodplain" => plasma_colors[8] 
    )

function segment_geometry(pts, max_lon_diff=30.0)
    segments = Vector{Point2f0}[]
    current_segment = Point2f0[]
    
    for pt in pts
        # Skip invalid coordinates
        if !isfinite(pt[1]) || !isfinite(pt[2]) || 
           abs(pt[1]) > 180 || abs(pt[2]) > 90
            continue
        end
        
        if isempty(current_segment)
            push!(current_segment, pt)
        else
            prev_lon = current_segment[end][1]
            curr_lon = pt[1]
            
            if abs(curr_lon - prev_lon) > max_lon_diff
                if length(current_segment) >= 3
                    push!(segments, copy(current_segment))
                end
                current_segment = Point2f0[pt]
            else
                push!(current_segment, pt)
            end
        end
    end
    
    if length(current_segment) >= 3
        push!(segments, current_segment)
    end
    
    return segments
end


for (geom, type) in zip(wetlands_geom, wetlands_type)
    try
        buffered_geom = ArchGDAL.buffer(geom, 1.25) #0.9 is a good value
        if ArchGDAL.isempty(buffered_geom) || !ArchGDAL.isvalid(buffered_geom)
            @warn "Invalid or empty geometry found"
            continue
        end
        ring = ArchGDAL.getgeom(buffered_geom, 0)
        n_points = ArchGDAL.ngeom(ring)
        pts = [Point2f0(ArchGDAL.getpoint(ring, i)[1],
                        ArchGDAL.getpoint(ring, i)[2]) for i in 0:n_points-1]
        
        # Add point validation
        if any(p -> !isfinite(p[1]) || !isfinite(p[2]), pts)
            @warn "Invalid coordinates found"
            continue
        end
        
        segments = segment_geometry(pts)
        for segment in segments
            if length(segment) >= 3
                # Add additional validation for the polygon
                if all(p -> -180 ≤ p[1] ≤ 180 && -90 ≤ p[2] ≤ 90, segment)
                    poly = GeometryBasics.Polygon(segment)
                    poly!(ga, poly, color = (wetland_colors[type], 0.9))
                end
            end
        end
    catch e
        @warn "Error processing geometry" exception=e
        continue
    end
end

scatter_p = scatter!(ga,
    longitude, 
    latitude, 
    color = :green,
    marker = :utriangle,  # upward-pointing triangle
    markersize = 12,
    strokewidth = 0.5,
    strokecolor = (:black, 0.4),
    alpha = 0.8
)

# Create separate legend elements for polygons and markers
poly_elements = [PolyElement(color = (color, 0.7)) for color in values(wetland_colors)]
poly_labels = collect(keys(wetland_colors))

marker_elements = [MarkerElement(color = :green, marker = :utriangle)]
marker_labels = ["Valuation Studies"]

# Combine all elements and labels
legend_elements = [poly_elements; marker_elements]
legend_labels = [poly_labels; marker_labels]

# Create legend
Legend(studies_wetlands_map[1, 2],
    legend_elements,
    legend_labels,
    "Legend",
    framevisible = false,
    labelsize = 12
)

# Adjust layout
colsize!(studies_wetlands_map.layout, 1, Relative(0.9))
colsize!(studies_wetlands_map.layout, 2, Relative(0.1))

# Create empty space between map and annotation using a new row
studies_wetlands_map[2, 1:2] = Label(studies_wetlands_map, " ", fontsize = 1)

# Add source attribution
studies_wetlands_map[2, 1:3] = Label(studies_wetlands_map, " ", fontsize = 1)

Label(studies_wetlands_map[2, 1:2], 
    "Data sources: ESVD, Global Wetland Clusters",
    fontsize = 10,
    padding = (0, 0, 20, 0),
    halign = :left
)

# Adjust the overall layout with better proportions
rowsize!(studies_wetlands_map.layout, 1, Relative(0.92))
rowsize!(studies_wetlands_map.layout, 2, Relative(0.08))  # Space between map and text

studies_wetlands_map

# Save svg
save("$(ENV["DIVA_DATA"])/graphs/svg/studies_wetlands_areas_map.svg", studies_wetlands_map)

# Save pdf
save("$(ENV["DIVA_DATA"])/graphs/pdf/studies_wetlands_areas_map.pdf", studies_wetlands_map)


