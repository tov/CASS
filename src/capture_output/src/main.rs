#![allow(dead_code)]

mod log {
    use std::collections::linked_list::{self as list, LinkedList as List};
    use std::default::Default;

    #[derive(Clone)]
    pub struct Log<T> {
        logs: List<Vec<T>>,
        len: usize,
    }

    impl<T> Default for Log<T> {
        fn default() -> Self {
            Log {
                logs: List::new(),
                len: 0,
            }
        }
    }

    impl<T> Log<T> {
        pub fn new() -> Self {
            Self::default()
        }

        pub fn len(&self) -> usize {
            self.len
        }

        pub fn capacity(&self) -> usize {
            self.len + self.reservation()
        }

        pub fn reservation(&self) -> usize {
            self.logs.back().map_or(0, |last| last.capacity() - last.len())
        }

        pub fn push(&mut self, item: T) {
            self.reserve(1);
            self.logs.back_mut()
                .expect("Log::push: bad reservation")
                .push(item);
            self.len += 1;
        }

        pub fn reserve(&mut self, additional: usize) {
            self.ensure_capacity(self.len() + additional);
        }

        fn ensure_capacity(&mut self, capacity: usize) {
            if self.capacity() < capacity {
                let capacity = capacity.max(2 * self.capacity());
                self.logs.push_back(Vec::with_capacity(capacity - self.capacity()));
            }
        }
    }

    trait NestedIterator: Iterator<Item=Self::IntoInner> {
        type IntoInner: IntoIterator<IntoIter=Self::InnerIter, Item=Self::InnerItem>;
        type InnerIter: Iterator<Item=Self::InnerItem>;
        type InnerItem;
    }

    impl<T> NestedIterator for T
        where
            T: Iterator,
            <T as Iterator>::Item: IntoIterator,
    {
        type IntoInner = T::Item;
        type InnerIter = <Self::IntoInner as IntoIterator>::IntoIter;
        type InnerItem = <Self::InnerIter as Iterator>::Item;
    }

    struct IterIter<I: NestedIterator> {
        first: I::InnerIter,
        rest: I,
        len: usize,
    }

    impl<I> Iterator for IterIter<I>
        where I: Iterator,
              <I as Iterator>::Item: IntoIterator,
    {
        type Item = <I as NestedIterator>::InnerItem;

        fn next(&mut self) -> Option<Self::Item> {
            loop {
                if let Some(value) = self.first.next() {
                    self.len -= 1;
                    return Some(value);
                } else {
                    self.first = self.rest.next()?.into_iter();
                }
            }
        }

        fn size_hint(&self) -> (usize, Option<usize>) {
            (self.len, Some(self.len))
        }
    }

    impl<I: NestedIterator> ExactSizeIterator for IterIter<I> {
        fn len(&self) -> usize {
            self.len
        }
    }

    pub struct IntoIter<T>(IntoIterRep<T>);
    type IntoIterRep<T> = IterIter<list::IntoIter<Vec<T>>>;

    pub struct Iter<'a, T>(IterRep<'a, T>);
    type IterRep<'a, T> = IterIter<list::Iter<'a, Vec<T>>>;

    impl<T> Iterator for IntoIter<T> {
        type Item = T;

        fn next(&mut self) -> Option<T> {
            self.0.next()
        }
    }

    impl<'a, T> Iterator for Iter<'a, T> {
        type Item = &'a T;

        fn next(&mut self) -> Option<&'a T> {
            self.0.next()
        }
    }

}

mod event {
    use tokio::time::Instant;

    #[derive(Clone, Debug)]
    pub struct Event<T> {
        what: T,
        when: Instant,
        whence: u32,
    }
}

use log::*;

#[tokio::main]
async fn main() {
    let mut log = Log::new();
    log.push("hello, ");
    log.push("world!");

    println!("Hello, world!");
}
