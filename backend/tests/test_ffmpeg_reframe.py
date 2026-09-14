from app.services.ffmpeg_utils import _piecewise_linear_expr, build_vertical_crop_filter


def test_piecewise_linear_expr_two_points_exact_string():
    expr = _piecewise_linear_expr([(0.0, 0.2), (3.0, 0.8)])
    assert expr == "if(lt(t\\,3.0000)\\,(0.2000+(0.8000-0.2000)*(t-0.0000)/(3.0000-0.0000))\\,0.8000)"


def test_piecewise_linear_expr_nests_for_three_points():
    expr = _piecewise_linear_expr([(0.0, 0.3), (2.0, 0.5), (4.0, 0.1)])
    # Two segments -> two nested if(lt(...)) branches, innermost holding
    # the final point's value for t beyond the last breakpoint.
    assert expr.count("if(lt(t\\,") == 2
    assert expr.endswith("0.1000))")


def test_piecewise_linear_expr_sorts_out_of_order_points():
    expr_sorted = _piecewise_linear_expr([(0.0, 0.2), (3.0, 0.8)])
    expr_unsorted = _piecewise_linear_expr([(3.0, 0.8), (0.0, 0.2)])
    assert expr_sorted == expr_unsorted


def test_build_vertical_crop_filter_centers_when_no_face_track():
    filt = build_vertical_crop_filter(src_w=1920, src_h=1080, target_ratio=9 / 16, face_track=[])
    crop_w = int(1080 * 9 / 16)
    expected_x = int(1920 / 2 - crop_w / 2)
    assert filt == f"crop={crop_w}:1080:{expected_x}:0"


def test_build_vertical_crop_filter_static_for_single_point():
    filt = build_vertical_crop_filter(src_w=1920, src_h=1080, target_ratio=9 / 16, face_track=[(0.0, 0.75)])
    crop_w = int(1080 * 9 / 16)
    expected_x = int(max(0, min(0.75 * 1920 - crop_w / 2, 1920 - crop_w)))
    assert filt == f"crop={crop_w}:1080:{expected_x}:0"


def test_build_vertical_crop_filter_clamps_offscreen_single_point():
    # A face detected right at the frame edge shouldn't push the crop
    # window past the source bounds.
    filt = build_vertical_crop_filter(src_w=1920, src_h=1080, target_ratio=9 / 16, face_track=[(0.0, 0.02)])
    crop_w = int(1080 * 9 / 16)
    assert filt == f"crop={crop_w}:1080:0:0"


def test_build_vertical_crop_filter_pans_across_multiple_points():
    filt = build_vertical_crop_filter(
        src_w=1920, src_h=1080, target_ratio=9 / 16, face_track=[(0.0, 0.3), (5.0, 0.7)]
    )
    crop_w = int(1080 * 9 / 16)
    assert filt.startswith(f"crop={crop_w}:1080:clip(")
    assert filt.endswith(":0")
    assert "if(lt(t\\," in filt
