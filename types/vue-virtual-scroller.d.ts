// Type declarations for vue-virtual-scroller
declare module 'vue-virtual-scroller' {
  import { DefineComponent } from 'vue'

  export interface RecycleScrollerProps {
    items: any[]
    keyField?: string
    itemSize?: number
    minItemSize?: number
    sizeField?: string
    typeField?: string
    direction?: 'vertical' | 'horizontal'
    listTag?: string
    itemTag?: string
    listClass?: string
    itemClass?: string
    gridItems?: number
    skipHover?: boolean
    buffer?: number
    prerender?: number
    emitUpdate?: boolean
  }

  export interface RecycleScrollerMethods {
    scrollToTop(): void
    scrollToBottom(): void
    scrollToItem(index: number): void
    getScroll(): { start: number; end: number }
    scrollToPosition(position: number): void
  }

  export const RecycleScroller: DefineComponent<RecycleScrollerProps, RecycleScrollerMethods>
  export const DynamicScroller: DefineComponent<any, any>
  export const DynamicScrollerItem: DefineComponent<any, any>
}
