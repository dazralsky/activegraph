Querying
========

Simple Query Methods
--------------------

There are a number of ways to find and return nodes.

``.find``
~~~~~~~~~

Find an object by `id_property` **(TODO: LINK TO id_property documentation)**

``.find_by``
~~~~~~~~~~~~

``find_by`` and ``find_by!`` behave as they do in ActiveRecord, returning the first object matching the criteria or nil (or an error in the case of ``find_by!``)

.. code-block:: ruby

  Post.find_by(title: 'Neo4j.rb is awesome')

Scope Method Chaining
---------------------

Like in ActiveRecord you can build queries via method chaining.  This can start in one of three ways:

 * ``Model.all``
 * ``Model.association``
 * ``model_object.association``

In the case of the association calls, the scope becomes a class-level representation of the association's model so far.  So for example if I were to call ``post.comments`` I would end up with a representation of nodes from the ``Comment`` model, but only those which are related to the ``post`` object via the ``comments`` association.

At this point it should be mentioned that what associations return isn't an ``Array`` but in fact an ``AssociationProxy``.  ``AssociationProxy`` is ``Enumerable`` so you can still iterate over it as a collection.  This allows for the method chaining to build queries, but it also enables :ref:`eager loading <active_node-eager_loading>` of associations

From a scope you can filter, sort, and limit to modify the query that will be performed or call a further association.

Querying the scope
~~~~~~~~~~~~~~~~~~

Similar to ActiveRecord you can perform various operations on a scope like so:

.. code-block:: ruby

  lesson.teachers.where(name: /.* smith/i, age: 34).order(:name).limit(2)

The arguments to these methods are translated into ``Cypher`` query statements.  For example in the above statement the regular expression is translated into a Cypher ``=~`` operator.  Additionally all values are translated into Neo4j `query parameters <http://neo4j.com/docs/stable/cypher-parameters.html>`_ for the best performance and to avoid query injection attacks.

Chaining associations
~~~~~~~~~~~~~~~~~~~~~

As you've seen, it's possible to chain methods to build a query on one model.  In addition it's possible to also call associations at any point along the chain to transition to another associated model.  The simplest example would be:

.. code-block:: ruby

  student.lessons.teachers

This would returns all of the teachers for all of the lessons which the students is taking.  Keep in mind that this builds only one Cypher query to be executed when the result is enumerated.  Finally you can combine scoping and association chaining to create complex cypher query with simple Ruby method calls.

.. code-block:: ruby

  student.lessons(:l).where(level: 102).teachers(:t).where('t.age > 34').pluck(:l)

Here we get all of the lessons at the 102 level which have a teacher older than 34.  The ``pluck`` method will actually perform the query and return an ``Array`` result with the lessons in question.  There is also a ``return`` method which returns an ``Array`` of result objects which, in this case, would respond to a call to the ``#l`` method to return the lesson.

Note here that we're giving an argument to the associaton methods (``lessons(:l)`` and ``teachers(:t)``) in order to define Cypher variables which we can refer to.  In the same way we can also pass in a second argument to define a variable for the relationship which the association follows:


.. code-block:: ruby

  student.lessons(:l, :r).where("r.start_date < {the_date} and r.end_date >= {the_date}").params(the_date: '2014-11-22').pluck(:l)

Here we are limiting lessons by the ``start_date`` and ``end_date`` on the relationship between the student and the lessons.  We can also use the ``rel_where`` method to filter based on this relationship:

.. code-block:: ruby

  student.lessons.where(subject: 'Math').rel_where(grade: 85)

Paramaters
~~~~~~~~~~

If you need to use a string in where, you should set the parameter manually.

.. code-block:: ruby

  Student.all.where("s.age < {age} AND s.name = {name} AND s.home_town = {home_town}")
    .params(age: params[:age], name: params[:name], home_town: params[:home_town])
    .pluck(:s)

The Query API
-------------

The ``neo4j-core`` gem provides a ``Query`` class which can be used for building very specific queries with method chaining.  This can be used either by getting a fresh ``Query`` object from a ``Session`` or by building a ``Query`` off of a scope such as above.

.. code-block:: ruby

  Neo4j::Session.current.query # Get a new Query object

  # Get a Query object based on a scope
  Student.query_as(:s)
  student.lessons.query_as(:l)

The ``Query`` class has a set of methods which map directly to Cypher clauses and which return another ``Query`` object to allow chaining.  For example:

  student.lessons.query_as(:l) # This gives us our first Query object
    .match("l-[:has_category*]->(root_category:Category)").where("NOT(root_category-[:has_category]->()))
    .pluck(:root_category)

Here we can make our own ``MATCH`` clauses unlike in model scoping.  We have ``where``, ``pluck``, and ``return`` here as well in addition to all of the other clause-methods.  See `this page <https://github.com/neo4jrb/neo4j-core/wiki/Queries>`_ for more details.

**TODO Duplicate this page and link to it from here (or just duplicate it here):**
https://github.com/neo4jrb/neo4j-core/wiki/Queries


``match_to`` and ``first_rel_to``
---------------------------------

There are two methods, match_to and first_rel_to that both make simple patterns easier.

In the most recent release, match_to accepts nodes; in the master branch and in future releases, it will accept a node or an ID. It is essentially shorthand for association.where(neo_id: node.neo_id) and returns a QueryProxy object.

.. code-block:: ruby

  # starting from a student, match them to a lesson based off of submitted params, then return students in their classes
  student.lessons.match_to(params[:id]).students

first_rel_to will return the first relationship found between two nodes in a QueryProxy chain.

.. code-block:: ruby

  student.lessons.first_rel_to(lesson)
  # or in the master branch, future releases
  student.lessons.first_rel_to(lesson.id)

This returns a relationship object.

Finding in Batches
------------------

Finding in batches will soon be supported in the neo4j gem, but for now is provided in the neo4j-core gem (documentation)

Orm_Adapter
-----------

You can also use the orm_adapter API, by calling #to_adapter on your class. See the API, https://github.com/ianwhite/orm_adapter