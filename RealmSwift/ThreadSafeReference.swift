////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Realm

/**
 An instance which is bound to a thread-specific `Realm` instance, and so cannot be passed
 between threads without being explicitly exported and imported.

 Instances conforming to this protocol can be converted to a thread-safe reference for transport
 between threads by passing to the `ThreadSafeReference(to:)` constructor.

 Note that only types defined by Realm can meaningfully conform to this protocol, and defining new
 classes which attempt to conform to it will not make them work with `ThreadSafeReference`.
 */
public protocol ThreadConfined {
    // Must also conform to `AssistedObjectiveCBridgeable`

    /// The Realm which manages the object, or `nil` if the object is unmanaged.
    var realm: Realm? { get }
#if swift(>=3.0)
    /// Indicates if the object can no longer be accessed because it is now invalid.
    var isInvalidated: Bool { get }
#else
    /// Indicates if the object can no longer be accessed because it is now invalid.
    var invalidated: Bool { get }
#endif
}

/**
 An object intended to be passed between threads containing a thread-safe reference to its
 thread-confined object.

 To resolve a thread-safe reference on a target Realm on a different thread, pass to
 `Realm.resolve(_:)`.

 - warning: Every `ThreadSafeReference` object created must be resolved exactly once.
            An exception will be thrown if a referenced is resolved more than once.
            The source Realm backing the referenced object will not advance until all its existing
            thread-safe references have been resolved. This means autorefresh and explicitly calling
            `Realm.refresh()` will fail until all references have been resolved or deallocated.

 - see: `Realm.resolve(_:)`
 */
public class ThreadSafeReference<Confined: ThreadConfined> {
    private let swiftMetadata: Any?
    private let type: ThreadConfined.Type
#if swift(>=3.0)
    private let objectiveCReference: RLMThreadSafeReference<RLMThreadConfined>
#else
    private let objectiveCReference: RLMThreadSafeReference
#endif

    /**
     Create a thread-safe reference to the thread-confined object.

     - param threadConfined: The thread-confined object to create a thread-safe reference to.
     */
    public init(to threadConfined: Confined) {
        // TODO: It might be necessary to check `invalidated` and `Realm` here. I'm not certain that bridging succeeds
        //       when these are false/nil.

        let bridged = (threadConfined as! AssistedObjectiveCBridgeable).bridged
        self.swiftMetadata = bridged.metadata
#if swift(>=3.0)
        self.type = type(of: threadConfined)
#else
        self.type = threadConfined.dynamicType
#endif
        self.objectiveCReference = RLMThreadSafeReference(threadConfined: bridged.objectiveCValue as! RLMThreadConfined)
    }

    internal func resolve(in realm: Realm) -> Confined? {
#if swift(>=3.0)
        guard let objectiveCValue = realm.rlmRealm.__resolve(objectiveCReference) else { return nil }
#else
        guard let objectiveCValue = realm.rlmRealm.__resolveThreadSafeReference(objectiveCReference) else { return nil }
#endif
        return ((Confined.self as! AssistedObjectiveCBridgeable.Type).bridging(from: objectiveCValue, with: swiftMetadata) as! Confined)
    }
}

extension Realm {
#if swift(>=3.0)
    /**
     Resolves the reference in the current Realm at its latest version for this thread.

     Returns the same object as the one referenced when the `ThreadSafeReference` was first created,
     advanced to the current Realm's version.

     Returns `nil` if this object was deleted after the reference was created, or if the thread
     hand-over operation failed.

     - parameter reference: The thread-safe reference to the thread-confined object to resolve in
                            this Realm.

     - returns: The thread-confined object referenced, advanced to the current Realm's version.

     - warning: Every `ThreadSafeReference` object created must be resolved exactly once.
                An exception will be thrown if a referenced is resolved more than once.
                The source Realm backing the referenced object will not advance until all its
                existing thread-safe references have been resolved. This means autorefresh and
                explicitly calling `Realm.refresh()` will fail until all references have been
                resolved or deallocated.

     - see: `ThreadSafeReference(to:)`
     */
    public func resolve<Confined: ThreadConfined>(_ reference: ThreadSafeReference<Confined>) -> Confined? {
        return reference.resolve(in: self)
    }
#else
    /**
     Resolves the reference in the current Realm at its latest version for this thread.

     Returns the same object as the one referenced when the `ThreadSafeReference` was first created,
     advanced to the current Realm's version.

     Returns `nil` if this object was deleted after the reference was created, or if the thread
     hand-over operation failed.

     - parameter reference: The thread-safe reference to the thread-confined object to resolve in
                            this Realm.

     - returns: The thread-confined object referenced, advanced to the current Realm's version.

     - warning: Every `ThreadSafeReference` object created must be resolved exactly once.
                An exception will be thrown if a referenced is resolved more than once.
                The source Realm backing the referenced object will not advance until all its
                existing thread-safe references have been resolved. This means autorefresh and
                explicitly calling `Realm.refresh()` will fail until all references have been
                resolved or deallocated.

     - see: `ThreadSafeReference(to:)`
     */
    public func resolve<Confined: ThreadConfined>(reference: ThreadSafeReference<Confined>) -> Confined? {
        return reference.resolve(in: self)
    }
#endif
}
