Path API
========

Design overview
---------------

The Path API models a mutable, ordered sequence of points (a doubly-linked list)
with deterministic ordering and optional branching. Each point carries a unique,
monotonic ID so that sorting of points at identical coordinates is stable across
environments. Points can be attached to share positions, linked into a path, or
serve as branch origins that spawn new paths. Paths own their points and provide
operations for insertion, removal, traversal, splitting, and geometric shaping.

All vectors referenced by this API are Luanti spatial vectors:
https://api.luanti.org/spatial-vectors/

Points and paths are created with deterministic unique IDs to ensure consistent
ordering across environments.

Points
======

Point constructors and helpers
------------------------------

* `point.new(pos)`
    * Creates a new point instance.
    * `pos` must be a vector (`{x=, y=, z=}`).
    * Errors if `pos` is not a vector.
    * Returns a point instance.

* `point.check(p)`
    * Returns `true` if `p` is a point, otherwise `false`.

* `point:copy()`
    * Returns a new point with the same position.
    * The copy is not linked, attached, or assigned to a path.

Point linkage
-------------

* `point.same_path(...)`
    * Returns `true` if all points belong to the same path.

* `point.link(...)`
    * Links points in order (doubly-linked list).
    * All points must belong to the same path.

* `point:unlink_from_previous()`
    * Unlinks from the previous point.

* `point:unlink_from_next()`
    * Unlinks from the next point.

* `point:unlink()`
    * Unlinks from both previous and next points.

Point attachment
----------------

Attached points share a position. When one moves, all attached points move.

* `point:attach(...)`
    * Attaches this point to the given points.
    * Attached points share the same position.

* `point:detach(...)`
    * Detaches this point from the given points.

* `point:detach_all()`
    * Detaches this point from all attached points.

* `point:set_position(pos)`
    * Sets position for this point and all attached points.
    * Errors if `pos` is not a vector.

Comparators and sorting
-----------------------

* `vector.comparator(v1, v2)`
    * Strict ordering by `x`, then `y`, then `z`.

* `point.equals(p1, p2)`
    * Returns `true` if positions match and IDs are equal.

* `point.comparator(p1, p2)`
    * Orders by position, then ID.

* `point.sort(points)`
    * Returns a sorted list of points.

* `point:attached_sorted()`
    * Returns attached points in deterministic order.

* `point:branches_sorted()`
    * Returns branches in deterministic order.

Iterators
---------

* `point:iterator()`
    * Iterates forward from this point through `next` links.
    * Returns `i, point`.

* `point:reverse_iterator()`
    * Iterates backward from this point through `previous` links.
    * Returns `i, point`.

Path assignment and branching
-----------------------------

* `point:set_path(pth)`
    * Assigns the point to `pth`.
    * Removes the point from its old path (if any) and adds it to the new one.

* `point:branch(finish)`
    * Creates a new path starting from a copy of this point and ending at `finish`.
    * Attaches the new path start to this point.
    * Returns the new path.

* `point:has_branches()`
    * Returns `true` if the point has branches.

* `point:unbranch(pth)`
    * Removes branch `pth` from this point.
    * If no branches remain, unmarks the point as a branching point.

* `point:unbranch_all()`
    * Removes all branches from this point.

* `point:clear()`
    * Unlinks, detaches, and unbranches this point.
    * Removes it from its path.

Paths
=====

Path constructors and helpers
-----------------------------

* `path.new(start, finish)`
    * Creates a new path.
    * `start` and `finish` must be points.
    * Returns a path instance.

* `path.check(pth)`
    * Returns `true` if `pth` is a path.

Intermediate point helpers
--------------------------

* `path:count_intermediate()`
    * Returns the number of intermediate points (excludes start/finish).

* `path:has_intermediate()`
    * Returns `true` if there is at least one intermediate point.

Comparators and sorting
-----------------------

* `path.comparator(pth1, pth2)`
    * Orders by start, finish, intermediate points, then ID.

* `path.sort(paths)`
    * Returns a sorted list of paths.

* `path:branching_points_sorted()`
    * Returns branching points in path order.

Start and finish
----------------

* `path:set_start(p)`
    * Sets the start point and reconnects the chain.

* `path:set_finish(p)`
    * Sets the finish point and reconnects the chain.

Point retrieval
---------------

* `path:get_point(nr)`
    * Returns the `nr`-th intermediate point, or `nil` if none.

* `path:get_points(from, to)`
    * Returns a list of intermediate points between `from` and `to`.

* `path:random_intermediate_point()`
    * Returns a random intermediate point, or `nil` if none exist.

* `path:point_in_path(p)`
    * Returns `true` if `p` is in the path.

Insertion
---------

* `path:insert_between(p_prev, p_next, p)`
    * Inserts `p` between adjacent points `p_prev` and `p_next`.

* `path:insert_at(nr, p)`
    * Inserts `p` at ordinal position `nr`.

* `path:insert_before(target, p)`
    * Inserts `p` before `target`.

* `path:insert_after(target, p)`
    * Inserts `p` after `target`.

* `path:insert(p)`
    * Inserts `p` before the finish point.

Removal
-------

* `path:remove(p)`
    * Removes intermediate point `p`.

* `path:remove_previous(p)`
    * Removes the intermediate point before `p`.

* `path:remove_next(p)`
    * Removes the intermediate point after `p`.

* `path:remove_at(nr)`
    * Removes the `nr`-th intermediate point.

Extend and shorten
------------------

* `path:extend(p)`
    * Adds `p` as the new finish point.

* `path:shorten()`
    * Removes the finish point and promotes the previous point.
    * Returns `true` if shortened.

* `path:shorten_by(nr)`
    * Shortens the path by `nr` points.

* `path:cut_off(stop_point)`
    * Removes all points after `stop_point`, making it the finish.

All points and positions
------------------------

* `path:all_points()`
    * Returns all points in order (start through finish).

* `path:all_positions()`
    * Returns positions of all points in order.

Length and geometry
-------------------

* `path:length()`
    * Returns total path length.

Segments
--------

* `path:all_segments()`
    * Returns a list of segment tables `{start_pos, end_pos, start_point, end_point}`.

Subdivide and unsubdivide
-------------------------

* `path:subdivide(segment_length)`
    * Inserts intermediate points so no segment exceeds `segment_length`.

* `path:unsubdivide(angle)`
    * Removes intermediate points that form a small angle with neighbors.

Split and transfer
------------------

* `path:transfer_points_to(pth, first, last)`
    * Transfers intermediate points `[first, last]` to `pth`.

* `path:split_at(p)`
    * Splits the path at intermediate point `p`.
    * Returns the newly created path.

Clear intermediate
------------------

* `path:clear_intermediate()`
    * Removes all intermediate points.

Path shape generators
---------------------

* `path:make_straight(segment_length)`
    * Leaves the path straight; optionally subdivides.

* `path:make_wave(segment_nr, amplitude, density)`
    * Creates a wavy path between start and finish.

* `path:make_slanted(segment_length)`
    * Creates a path with one 45° break where applicable; optionally subdivides.