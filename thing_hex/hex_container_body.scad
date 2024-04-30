//
// Predefine 3 containers, a small, medium, and large container
//
small = 0; medium = 1; large = 2;

//
// Choose the small container, and draw both the container
// and the cap
//
form = small;

// 1 draws,     0 does not draw
draw_container = 1;
draw_cap = 0;

//
// I've been using a 27mm height (depth) for my containers
// multiplied by some number (i.e., 1, 1.5, 2, 2.5, etc)
// depending on how much volume I need to fit whatever
// the container will hold.
//
height_multiplier = 1.0;

//
// Increasing global_fn makes curves smoother at the cost of
// frame rate / render time.
//
global_fn = 500;


// The containers need to interlock, so there needs to be a bit
// of "gap" between the positive and negative spaces. The lower
// this number is the tighter the fit will be, but at a certian point
// the containers won't go together anymore.
//
// Unfortunately, the fit seems to be slicer dependent.  .5 worked
// well for me.
//
gap = .5;

//
// This is the total height (depth) of the container. I use 27mm
// and some multiplier, so the containers stack well.
//
total_depth = 27*height_multiplier;

// how many mm deep should the thread top be
thread_depth = 7;

// How much room do you have for the container part
// (total - thread part )
mid_depth = total_depth - thread_depth;

// Parameters you can adjust or play with :)
top_walls = [5, 7, 9 ];
top_wall = top_walls[ form ];
mid_top_walls = [4, 4, 5 ];
mid_top_wall = mid_top_walls[ form ];
mid_mid_wall = 2;
bot_floor = 2;
thread_cyl_wall = 2.0;
thread_inner_diams = [30, 50, 70 ];
thread_inner_diam = thread_inner_diams[ form ];
slot_width = 2.2;

// Used to compensate for floating point round off errors,
// 1/100th of a mm.
epsilon = .01;

// @brief Create a hollow cylinder (ring)
//
// @param depth
//      The depth (or height) of the ring.
// @param inner_diam
//      The inner diameter of the cylinder
// @param wall
//      The size of the cylinder's wall
// @param fn
//      The fn used to create the cylinder.  Higher fn
//      is smoother, but more computationally expensive
//
module ring_fn( depth, inner_diam, wall, fn ) {
    rotate_extrude($fn=fn) polygon( points=[
        [inner_diam/2, 0 ],
        [inner_diam/2, depth],
        [inner_diam/2+wall, depth ],
        [inner_diam/2+wall, 0 ]]);

}

//
// @brief Create a partial cone
//
// "Just like ring_fn, but with a different bottom and top diameter"
//
// @param depth
//      The depth of the partial cone
// @param l_innder_diam
//      The lower inner diameter (i.e, the diameter at z = 0 )
// @param u_inner_diam
//      The upper inner diameter (i.e., the diameter at z = depth )
// @param l_wall
//      The wall size at z = 0
// @param u_wall
//      The wall size at z = depth
// @param fn
//      The fn used to create the partial.  Higher fn
//      is smoother, but more computationally expensive
//
module partial_cone_fn( depth, l_inner_diam, u_inner_diam, l_wall, u_wall, fn ) {
        rotate_extrude($fn=fn) polygon( points=[
        [l_inner_diam/2, 0 ],
        [u_inner_diam/2, depth],
        [u_inner_diam/2+u_wall, depth ],
        [l_inner_diam/2+l_wall, 0 ]]);
}

// @brief Creae a thread
// 
// The thread is centered at x=0, y=0, and goes along the z axis
//
// @param thread_z_per_rotation
//      How much does the thread go up with each rotation, in mm
// @param thread_width
//      How thick is each thread, in mm
// @param cylinder_radius
//      The radius of the cylinder that the thread wraps. A "thread"
//      object and a cylinder gives you a screw
// @param thread_top_height
//      The thread starts at "z=thread_top_height" and goes down,
//      depending on how many rotations the caller wants.

module thread( 
    thread_z_per_rotation,
    thread_width,
    cylinder_radius,
    thread_top_height,
    thread_rotations_arg 
)
{
    thread_rotations = thread_rotations_arg;
    
    // We need to have our threads on 45 degree angles so
    // we don't need supports, so the thread depth always
    // has to be half the width
    
    thread_depth = thread_width/2;
    
    // The actual side of the cube is the thread width
    // is rotated 45 degrees
    //  ___
    //   |                   /\                       
    //   |                  /90\
    //  thread_depth      /    \
    // =thread_width/2   /      \ thread_cube_side
    //   |                /        \
    //   |               /          \
    //   |              / 45      45 \
    //  ---             ---------------                  
    //                 | thread_width |
    //
    // thread_cube_side * cos( 45 ) = thread_depth
    // thread_cube_side = thread_depth / cos( 45 )
    //
    
    thread_cube_side = thread_depth / cos(45);

    // We'll want to know the radius of the thread
    outer_thread_radius = cylinder_radius + thread_depth;    
    
    // We'll make our thread usign a for loop, using cubes.
    // This means I plan to lay down a cube every 5 degrees
    step_angle = 5;

    PI =  3.1415;
    
    // Figure out the length of the thread after one rotation,
    // along the outer radius of the thread.
    one_rotation_length = outer_thread_radius * PI * 2;
    
    // I want to rotate the cubes I'll be making so they're
    // pitched very slightly down.  If I make a triangle with
    // the length of the thread for one rotation on the bottom
    // and the amunt the thread dropped on the side, the
    // angle I rotate to rotate my cubes is shown below.  I can
    // compute that angle with an arc tangent
    //
    //
    //                      XXXXXXX        ---
    //               XXXXXXX           |    | thread_z_per_rotation
    //        XXXXXXX                  |    |
    // XXXXXXX <- pitch_down_angle  |   ---
    // ----------------------------
    // |    one_rotation_length    |
    
    pitch_down_angle = atan( thread_z_per_rotation / one_rotation_length );    
   
    
    intersection() {
        // I'm going to use a big cylinder to clip the thread
        // that I'm making.  Multiplying the cylinder_radius by
        // 2 should be enough.
        
        cylinder( thread_top_height, 
            cylinder_radius * 2, cylinder_radius * 2 );        
        
        // Now start laying down cubes usign a for loop
        
        for ( angle = [0 : step_angle : 360 * thread_rotations ] ) {
            
            //                 --|--------________
            //                   |                --------________
            // segment_length  |                                --------
            //                   |                ________--------
            //                 --|________--------
            //           outer_thread_radius
            
            segment_length = outer_thread_radius * sin( step_angle / 2 ) * 2;
            
            cube_length =  
                segment_length * 
                // Increase the length a bit to adjust for the pitch
                // down (we effectively lose a bit of length here )
                ( 1 / cos( pitch_down_angle ));
        
            rotate( -angle, [0, 0, 1 ] )
            translate( [ cylinder_radius, 0, 
                thread_top_height - angle /360 * thread_z_per_rotation + thread_width/2 ] )
            rotate( pitch_down_angle, [ 1, 0, 0 ] )
            rotate( 45, [ 0, 1, 0 ])
                cube([thread_cube_side,
                    cube_length, thread_cube_side  ], center=true );
        }

    }
}

//
// Male and Female Slots...
//
// The sides of the hex container have alternating male 
// and female slots that are designed to lock in place with 
// other containers of the same type.
//

//
// @brief The female slot - these interlock with the "male" slots
//
// @param width - How wide is the slot?
// @param height - How high is the slot?
//
module female_slot( width, height )
{  
    x_left_side = -width/2;
    x_right_side = width/2;
    x_left_slot_inner =     x_left_side    + ( slot_width - gap/2 );
    x_left_slot_outer =     x_left_side    + ( slot_width*2  );
    x_right_slot_inner =    x_right_side   - ( slot_width - gap/2);    
    x_right_slot_outer =    x_right_side   - ( slot_width*2  );
    
    y_attach_point = epsilon;
    y_slot_inner =          y_attach_point - slot_width - gap;
    y_slot_outer =          y_attach_point - slot_width*2;
    
    linear_extrude( height ) polygon( points=[
        [ x_left_side,          y_attach_point ],
        [ x_left_side,          y_slot_outer ],
        [ x_left_slot_outer,    y_slot_outer ],
        [ x_left_slot_outer,    y_slot_inner ],
        [ x_left_slot_inner,    y_slot_inner ],
        [ x_left_slot_inner,    y_attach_point ]
    ]);
    linear_extrude( height ) polygon( points=[
        [ x_right_side,          y_attach_point ],
        [ x_right_side,          y_slot_outer ],
        [ x_right_slot_outer,    y_slot_outer ],
        [ x_right_slot_outer,    y_slot_inner ],
        [ x_right_slot_inner,    y_slot_inner ],
        [ x_right_slot_inner,    y_attach_point ]
    ]);    
}

//
// @brief The female slot - these interlock with the "female" slots
//
// @param width - How wide is the slot?
// @param height - How high is the slot?
//
module male_slot( width, height )
{  
    x_left_side = -width/2;
    x_right_side = width/2;
    x_left_slot_outer =     x_left_side    + ( slot_width + gap/2 );
    x_left_slot_inner =     x_left_side    + ( slot_width*2 + gap/2 );
    x_right_slot_outer =    x_right_side   - ( slot_width + gap/2 );    
    x_right_slot_inner =    x_right_side   - ( slot_width*2 + gap/2 );
    
    y_attach_point = epsilon;
    y_slot_inner =          y_attach_point - slot_width - gap;
    y_slot_outer =          y_attach_point - slot_width*2;
    
    linear_extrude( height ) polygon( points=[
        [ x_left_slot_inner,     y_attach_point ],
        [ x_left_slot_inner,     y_slot_inner ],
        [ x_left_slot_outer,     y_slot_inner ],
        [ x_left_slot_outer,     y_slot_outer ],
        [ x_right_slot_outer,    y_slot_outer ],
        [ x_right_slot_outer,    y_slot_inner ],
        [ x_right_slot_inner,    y_slot_inner ],
        [ x_right_slot_inner,    y_attach_point ]
    ]);    
}

module all_interlocking_slots()
{
    // slot_attach is how for out from the center the slots
    // go.  It's the inner radius of the opening plus the top
    // wall. cos(30) gives "the edge we're attaching to" /
    // "the corner of the hex"
    //
    slot_attach = (thread_inner_diam/2 + top_wall)*cos(30);
    
    //
    // Create 3 pairs of female and male slots 120 degrees apart.
    //
    for ( angle = [ 0 : 120 : 240 ] ) {
        rotate(angle,[0,0,1])        
        translate( [0, -slot_attach, 0 ] ) 
            female_slot( slot_attach / cos(30), mid_depth +    thread_depth );    
        rotate(angle + 60 ,[0,0,1])
        translate( [0, -slot_attach, 0 ] ) 
            male_slot( slot_attach / cos(30), mid_depth + thread_depth );       
    }
}

//
// The "inner" hex container is the hex container without the
// interlocking slots.  It's created using constructive solid
// geometry.
//
// positive space:
//      - Hexagonal Floor
//      - Hexagonal Walls,
//      - A Hexagonal "Bevel" from the walls to the top.  The
//        bevel gives a 45 degree slope from the walls to the top,
//        so supports aren't needed.
//      - The Hexagonal Top.  This is where the cap screws into
//
// negative space:
//      - The hole at the top (a cylinder)
//      - The screw
//
// The hexagonal "bevel" is a tiny bit smaller than the cylinder
// opening at the top - this is to keep the cap from falling 
// through when you screw it in.
//
//

//
// @brief Inner Container Positive Space
//
// @see documentation above :)
//
module inner_container_pos()
{
    // Go from the bottom to the top of the container.

    // Hexagonal Floor
    cylinder( r=thread_inner_diam/2+top_wall, h=bot_floor, $fn=6 );    

    //
    // We need to work out the height of the bevel here.
    // We want to come in just enough that the cap won't
    // fall through.
    //
    mid_bevel = mid_top_wall - mid_mid_wall;

    // Hexagonal Walls.  
    ring_fn( mid_depth - mid_bevel , thread_inner_diam+(top_wall-mid_mid_wall)*2, mid_mid_wall, 6 );
    
    // The Hexagonal "Wall to Top" bevel
    translate([0,0, mid_depth - mid_bevel ])
    partial_cone_fn( mid_bevel, 
        thread_inner_diam+(top_wall-mid_mid_wall)*2,
        thread_inner_diam+(top_wall-mid_top_wall)*2,
        mid_mid_wall,
        mid_top_wall,
        6 );
        
    // The Hexagonal Top
    translate([0,0, mid_depth ])
        ring_fn( thread_depth, thread_inner_diam, top_wall, 6 );
    
}

//
// @brief Inner Container Negative Space
//
// @see documentation above :)
//
module inner_container_neg()
{
    // The Cylinder opening for the container
    translate([0,0,mid_depth])
        cylinder( thread_depth, r=thread_inner_diam/2, $fn=100 );
    
    // The Screw Threads.
    translate( [0, 0, mid_depth ] )
        thread( 3, 3, thread_inner_diam/2, thread_depth, 5 );
}

//
// @brief The actual hex container, minus the cap
//
module container() 
{
    // Create the container by constructing the inner container
    // (the bit without the interlocking slots) and then adding
    // the slots.
    
    difference() {
        inner_container_pos();
        inner_container_neg();
    }
    
    all_interlocking_slots();
}



module usb_cap_pos() {


    thread( 3, 2, sc_inner_diam/2, thread_depth, 5 );
}

// @brief Cube centered in x and y, with a base at z=0
//
// @param x     x dimenion
// @param y     y dimension
// @param z     z dimension
//
module scube( x, y, z ) {
    translate([0,0,z/2])
    cube([x,y,z],center=true);
}

// @brief Draw a cap
//
// @param top_text 
//      The lettering at the top of the cap
// @param bot_text
//      The lettering at the bottom of the cap
// @param text_size
//      The size of the font.
// 
module cap( top_text, bot_text, text_size ) {
    cap_floor = 2;
    cap_wall = 1;

    //
    // thread_inner_diam is the inner diameter of the thread
    // on the container. We need to shrink the cap's inner
    // diam just a bit (.5mm) so it'll fit into the container
    //
    cap_thread_inner_diam = thread_inner_diam - .5;
    
    // Start with the floor
    cylinder( cap_floor, r=cap_thread_inner_diam/2, $fn=100 );   

    // Add the outer cylinder
    ring_fn( thread_depth, cap_thread_inner_diam - cap_wall*2, cap_wall, 100 );  

    // Add the screw to the outside
    thread( 3, 2, cap_thread_inner_diam/2, thread_depth, 5 );

    // Finally, add the lettering and the horizontal bar
    //
    // The angle here is my best attempt to make a cap that
    // lines up with the hex edge when you screw it in. 
    // The final "screwed in" angle seems to depend on 
    // slicer setting (which isn't super surprising).
    //
    rotate(40-360/12,[0,0,1]) union() {
        // Create a horizontal bar for turning the cap
        scube( cap_thread_inner_diam - cap_wall/2, cap_wall*2, thread_depth);    
        // Do Lettering
        translate([0,cap_thread_inner_diam/5,2])    
        linear_extrude( 3 ) text(top_text, halign="center", valign="center", size=text_size);
        translate([0,-cap_thread_inner_diam/5,2])    
        linear_extrude( 3 ) text(bot_text, halign="center", valign="center", size=text_size);
    }
}

//
// Spread the cap and the container out a bit.
//
spacing = thread_inner_diam + top_wall*2 + 5;

if ( draw_container ) {
    translate([spacing/2, 0,0])
    container();
}

if ( draw_cap ) 
{   
    translate([-spacing/2,0,0])
    cap("Small", "Cap", 7 );
}

