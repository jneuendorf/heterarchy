# spec.heterarchy
# ===============
#
# > This file is part of [Heterarchy](http://sinusoid.es/heterarchy).
# > - **View me [on a static web][sinusoid]**
# > - **View me [on GitHub][g]**
#
# [sinusoid]: http://sinusoid.es/heterarchy/heterarchy.html
# [g]: https://github.com/arximboldi/heterarchy/blob/master/heterarchy.litcoffee
#
# Tests for multiple inheritance support.
#
# Most test heterarchies are taken from the [original C3
# paper](http://192.220.96.201/dylan/linearization-oopsla96.html)


# node.js
if typeof global is "object" and global?.global is global
    chai = require 'chai'
    heterarchy = require '../heterarchy'
# browser
else
    chai = window.chai
    heterarchy = window.heterarchy

{expect} = chai
should = do chai.should


describe 'heterarchy', ->

    {
        multi
        mro, bases, hierarchy, inherited
        isinstance, issubclass
    } = heterarchy

    # Hierarchies to test
    # -------------------
    #
    # Class heterarchy from the Dylan paper, figure 5. Make sure the
    # linearization respects the *Extended Precedence Graph*.

    class Pane
    class EditingMixin
    class EditablePane extends multi Pane, EditingMixin
    class ScrollingMixin
    class ScrollablePane extends multi Pane, ScrollingMixin
    class EditableScrollablePane extends multi ScrollablePane, EditablePane

    # Class heterarchy from the Dylan paper, figure 4. Example of
    # compatibility with CLOS.

    class ChoiceWidget
    class PopupMixin
    class Menu extends ChoiceWidget
    class NewPopupMenu extends multi Menu, PopupMixin, ChoiceWidget

    # Class heterarchy from the Dylan paper, figure 2.  Make sure
    # linearization is monotonic.

    class Boat
    class DayBoat extends Boat
    class WheelBoat extends Boat
    class EngineLess extends DayBoat
    class SmallMultiHull extends DayBoat
    class PedalWheelBoat extends multi EngineLess, WheelBoat
    class SmallCatamaran extends SmallMultiHull
    class Pedalo extends multi PedalWheelBoat, SmallCatamaran

    # Hierarchy of classes with methods and constructors that use
    # super.

    class A
        constructor: ->
            @a = 'a'
        method: -> "A"
        @classMethod: -> "A"
        @overrideNoSuper: -> "a"

    class B extends A
        constructor: ->
            super
            @b = 'b'
        method: -> "B>#{super}"
        @classMethod: -> "B>#{super}"
        @overrideNoSuper: -> "b"

    class C extends A
        constructor: ->
            super
            @c = 'c'
        method: -> "C>#{super}"
        @classMethod: -> "C>#{super}"
        @overrideNoSuper: -> "c"

    class D extends multi B, C
        constructor: ->
            super
            @d = 'd'
        method: -> "D>#{super}"
        @classMethod: -> "D>#{super}"
        @overrideNoSuper: -> "d"

    class E extends A
        constructor: ->
            super
            @e = 'e'
        method: -> "E>#{super}"
        @classMethod: -> "E>#{super}"
        @overrideNoSuper: -> "e"

    class F extends multi C, E
        constructor: ->
            super
            @f = 'f'
        method: -> "F>#{super}"
        @classMethod: -> "F>#{super}"
        @overrideNoSuper: -> "f"

    class G extends multi D, F
        constructor: ->
            super
            @g = 'g'
        method: -> "G>#{super}"
        @classMethod: -> "G>#{super}"
        @overrideNoSuper: -> "g"

    # Hierarchy of classes where classes that only inherit from
    # `object` magically get a superclass in a multiple inheritance
    # context.

    class Base1
        classProperty: 42
        constructor: ->
            @base1 = 'base1'

    class Base2
        classProperty: ->
            'something'
        constructor: ->
            @base2 = 'base2'

    class Deriv extends multi Base1, Base2
        constructor: ->
            super
            @deriv = 'deriv'


    # Tests
    # -----

    describe 'mro', ->

        it 'generates empty linearization for arbitrary object', ->
            (mro {}).should.eql []

        it 'generates empty linearization for null object', ->
            (mro undefined).should.eql []
            (mro null).should.eql []

        it 'generates a monotonic linearization', ->
            (mro Pedalo).should.eql [
                Pedalo, PedalWheelBoat, EngineLess, SmallCatamaran,
                SmallMultiHull, DayBoat, WheelBoat, Boat, Object]

        it 'respects local precedence', ->
            (mro NewPopupMenu).should.eql [
                NewPopupMenu, Menu, PopupMixin, ChoiceWidget, Object]

        it 'respects the extended precedence graph', ->
            (mro EditableScrollablePane).should.eql [
                EditableScrollablePane, ScrollablePane, EditablePane,
                Pane, ScrollingMixin, EditingMixin, Object ]


    describe 'bases', ->
        it 'works with non-subclasses', ->
            (bases A).should.eql []

        it 'retrieves bases of single-inherited classes', ->
            (bases B).should.eql [A]
            (bases C).should.eql [A]

        it 'retrieves bases of multi-inherited classes', ->
            (bases D).should.eql [B, C]
            (bases G).should.eql [D, F]


    describe 'multi', ->

        describe 'instance methods', ->

            it 'calls super properly in multi case', ->
                obj = new D
                (mro D).should.eql [D, B, C, A, Object]
                obj.method().should.equal 'D>B>C>A'

            it 'calls super properly in recursive multi case', ->
                obj = new G
                (mro G).should.eql [G, D, B, F, C, E, A, Object]
                obj.method().should.equal 'G>D>B>F>C>E>A'


        describe 'class methods', ->

            it 'calls super properly in multi case', ->
                D.classMethod().should.equal 'D>B>C>A'

            it 'calls super properly in recursive multi case', ->
                # method is overridden
                G.classMethod().should.equal 'G>D>B>F>C>E>A'

                # closure for not overwriting the value of e.g. `A`
                do (A, B, C) ->
                    # method is not overridden
                    class A
                        @classMethod: ->
                            return super + 'Base1'

                    class B
                        @classMethod: ->
                            return 'Base2'

                    class C extends multi A, B

                    C.classMethod().should.equal 'Base2Base1'

            it 'overrides class methods properly in recursive multi case', ->
                # exclude Object
                for cls in mro(G)[0...-1]
                    cls.overrideNoSuper().should.equal cls.name.toLowerCase()

        it 'gets constructed properly', ->
            obj = new D
            obj.d .should.equal 'd'
            obj.c .should.equal 'c'
            obj.b .should.equal 'b'
            obj.a .should.equal 'a'

        it 'can generate the original hierarchy when possible', ->
            (hierarchy D).should.not.eql mro D
            (hierarchy inherited D).should.not.eql mro(D)[1..]
            (hierarchy inherited inherited D).should.eql mro(D)[2..]

        it 'memoizes generated superclasses', ->
            (inherited D).should.equal multi B, C

        it 'throws error on inconsistent hierarchy', ->
            (-> multi D, C, B)
                .should.throw "Inconsistent multiple inheritance"

            ((A, B, C) ->
                class A
                class B extends A
                class C extends multi A, B)
            .should.throw "Inconsistent multiple inheritance"

        it 'makes sure the next constructor after a root class', ->
            obj = new Deriv
            obj.base1 .should.equal 'base1'
            obj.base2 .should.equal 'base2'
            obj.deriv .should.equal 'deriv'

        it 'allows accessing class properties', ->
            obj = new Deriv
            obj.classProperty .should.equal 42

        it 'allows class properties to be set via object', ->
            obj = new Deriv
            obj.classProperty = 12
            obj.classProperty .should.equal 12
            Deriv::classProperty .should.equal 42

        it 'does not polute core classes', ->
            should.not.exist Object::__mro__
            should.not.exist Function::__mro__
            should.not.exist Number::__mro__
            should.not.exist Boolean::__mro__
            should.not.exist String::__mro__

            if typeof Promise isnt "undefined"
                should.not.exist Promise::__mro__
            if typeof Map isnt "undefined"
                should.not.exist Map::__mro__
            if typeof Set isnt "undefined"
                should.not.exist Set::__mro__


        describe 'freezes class properties', ->
            # This is just a limitation of the approach and these
            # tests are here to document it.  Ideally we would get rid
            # of it in the future.
            it 'makes changes invisible to children', ->
                obj = new Deriv
                Base1::classProperty = 12
                Deriv::classProperty .should.equal 42
                obj.classProperty .should.equal 42

            it 'makes new properties invisible to children', ->
                obj = new Deriv
                Base1::newClassProperty = 'sth'
                should.not.exist Deriv::newClassProperty
                should.not.exist obj.newClassProperty


    describe 'isinstance', ->

        it 'checks the classes of an object even with multiple inheritance', ->
            (isinstance new D, D).should.be.true
            (isinstance new D, B).should.be.true
            (isinstance new D, C).should.be.true
            (isinstance new D, A).should.be.true
            (isinstance new D, Object).should.be.true
            (isinstance new A, Object).should.be.true
            (isinstance new Object, A).should.be.false
            (isinstance new Pedalo, D).should.be.false
            (isinstance new Pedalo, A).should.be.false
            (isinstance new Pedalo, SmallCatamaran).should.be.true


    describe 'issubclass', ->

        it 'checks the relations of classes even with multiple inheritance', ->
            (issubclass D, D).should.be.true
            (issubclass D, B).should.be.true
            (issubclass D, C).should.be.true
            (issubclass D, A).should.be.true
            (issubclass D, Object).should.be.true
            (issubclass A, Object).should.be.true
            (issubclass Object, A).should.be.false
            (issubclass Pedalo, D).should.be.false
            (issubclass Pedalo, A).should.be.false
            (issubclass Pedalo, SmallCatamaran).should.be.true

# License
# -------
#
# Copyright (c) 2013, 2015 Juan Pedro Bolivar Puente <raskolnikov@gnu.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# >
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# >
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
