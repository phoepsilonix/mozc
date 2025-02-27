// Copyright 2010-2021, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "renderer/mac/CandidateView.h"

#include "base/coordinates.h"
#include "protocol/commands.pb.h"
#include "renderer/mac/CandidateController.h"
#include "renderer/mac/CandidateWindow.h"
#include "renderer/mac/InfolistWindow.h"
#include "renderer/mac/mac_view_util.h"
#include "renderer/table_layout.h"
#include "renderer/window_util.h"

namespace mozc {
using client::SendCommandInterface;
using commands::RendererCommand;

namespace renderer {
namespace mac {

namespace {
const int kHideWindowDelay = 500;  // msec
const int kWindowMargin = 10;      // pixel

// In Cocoa's coordinate system the origin point is left-bottom and the Y-axis
// points up. But in Mozc's coordinate system the Y-axis points down. So we use
// OriginPointInCocoaCoord and RectInMozcCoord to convert the coordinate system.
NSPoint OriginPointInCocoaCoord(const mozc::Rect &rect) {
  return NSMakePoint(rect.Left(), -rect.Bottom());
}

mozc::Rect RectInMozcCoord(const NSRect &rect) {
  return mozc::Rect(rect.origin.x, -rect.origin.y - rect.size.height, rect.size.width,
                    rect.size.height);
}

// Find the display including the specified point and if it fails to
// find it, pick up the nearest display.  Returns the geometry of the
// found display.
mozc::Rect GetNearestDisplayRect(const mozc::Rect &rect) {
  NSPoint point = OriginPointInCocoaCoord(rect);
  float nearest_distance = FLT_MAX;
  NSRect result_rect = NSMakeRect(0, 0, 0, 0);
  for (NSScreen *screen in [NSScreen screens]) {
    NSRect rect = [screen frame];
    CGFloat distance = 0;
    if (point.x < rect.origin.x) {
      distance += rect.origin.x - point.x;
    } else if (point.x > rect.origin.x + rect.size.width) {
      distance += point.x - rect.origin.x - rect.size.width;
    }
    if (point.y < rect.origin.y) {
      distance += rect.origin.y - point.y;
    } else if (point.y > rect.origin.y + rect.size.height) {
      distance += point.y - rect.origin.y - rect.size.height;
    }

    if (distance < nearest_distance) {
      nearest_distance = distance;
      result_rect = rect;
    }
  }
  return RectInMozcCoord(result_rect);
}

// Returns the height of the base screen.
int GetBaseScreenHeight() {
  NSRect baseFrame = NSZeroRect;
  for (NSScreen *baseScreen in [NSScreen screens]) {
    baseFrame = [baseScreen frame];
    if (baseFrame.origin.x == 0 && baseFrame.origin.y == 0) {
      break;
    }
  }
  return baseFrame.size.height;
}

}  // namespace

CandidateController::CandidateController()
    : candidate_window_(new mac::CandidateWindow),
      cascading_window_(new mac::CandidateWindow),
      infolist_window_(new mac::InfolistWindow) {
  candidate_window_->SetWindowLevel(NSPopUpMenuWindowLevel);
  // Cascading window should be over the normal candidate window.
  cascading_window_->SetWindowLevel(NSPopUpMenuWindowLevel + 1);
  // Infolist window should be under the normal candidate window.
  infolist_window_->SetWindowLevel(NSPopUpMenuWindowLevel - 1);
}

CandidateController::~CandidateController() {
  delete candidate_window_;
  delete cascading_window_;
  delete infolist_window_;
}

bool CandidateController::Activate() {
  // Do nothing
  return true;
}

bool CandidateController::IsAvailable() const { return true; }

void CandidateController::SetSendCommandInterface(SendCommandInterface *send_command_interface) {
  candidate_window_->SetSendCommandInterface(send_command_interface);
  cascading_window_->SetSendCommandInterface(send_command_interface);
  infolist_window_->SetSendCommandInterface(send_command_interface);
}

bool CandidateController::ExecCommand(const RendererCommand &command) {
  if (command.type() != RendererCommand::UPDATE) {
    return false;
  }
  command_.CopyFrom(command);

  if (!command_.visible()) {
    candidate_window_->Hide();
    cascading_window_->Hide();
    infolist_window_->Hide();
    return true;
  }

  candidate_window_->SetCandidateWindow(command_.output().candidate_window());

  bool cascading_visible = false;
  if (command_.output().has_candidate_window() &&
      command_.output().candidate_window().has_sub_candidate_window()) {
    cascading_window_->SetCandidateWindow(command_.output().candidate_window().sub_candidate_window());
    cascading_visible = true;
  }

  bool infolist_visible = false;
  if (command_.output().has_candidate_window() &&
      command_.output().candidate_window().has_usages() &&
      command_.output().candidate_window().usages().information_size() > 0) {
    infolist_window_->SetCandidateWindow(command_.output().candidate_window());
    infolist_visible = true;
  }

  AlignWindows();
  candidate_window_->Show();
  if (cascading_visible) {
    cascading_window_->Show();
  } else {
    cascading_window_->Hide();
  }

  if (infolist_visible && !cascading_visible) {
    const commands::CandidateWindow &candidate_window = command_.output().candidate_window();
    if (candidate_window.has_focused_index() && candidate_window.candidate_size() > 0) {
      const int focused_row =
          candidate_window.focused_index() - candidate_window.candidate(0).index();
      if (candidate_window.candidate_size() >= focused_row &&
          candidate_window.candidate(focused_row).has_information_id()) {
        infolist_window_->DelayShow(candidate_window.usages().delay());
      } else {
        infolist_window_->DelayHide(kHideWindowDelay);
      }
    } else {
      infolist_window_->DelayHide(kHideWindowDelay);
    }
  } else {
    // Hide infolist window immediately.
    infolist_window_->Hide();
  }

  return true;
}

void CandidateController::AlignWindows() {
  // If candidate window is not visible, we do nothing for aligning.
  if (!command_.has_preedit_rectangle()) {
    return;
  }

  const mozc::Size preedit_size(
      command_.preedit_rectangle().right() - command_.preedit_rectangle().left(),
      command_.preedit_rectangle().bottom() - command_.preedit_rectangle().top());
  // The origin point of command_.preedit_rectangle() is the left-top of the
  // base screen which is set in MozcImkInputController. It is
  // unnecessary calculation but to support older version of GoogleJapaneseInput
  // process we should not change it. So we minus the height of the screen here.
  mozc::Rect preedit_rect(mozc::Point(command_.preedit_rectangle().left(),
                                      command_.preedit_rectangle().top() - GetBaseScreenHeight()),
                          preedit_size);

  // This is a hacky way to check vertical writing.
  // TODO(komatsu): We should use the return value of attributesForCharacterIndex
  // in MozcImkInputController as a proper way.
  const bool is_vertical = (preedit_size.height < preedit_size.width);

  // Expand the rect size to make a margin to the candidate window.
  if (is_vertical) {
    // Adjust the margin to the candidate window in the right side.
    preedit_rect.DeflateRect(0, 0, -kWindowMargin, 0);  // (dx, dy, dw, dh)
  } else {
    // Adjust the margin to the candidate window in the upper side.
    preedit_rect.DeflateRect(0, -kWindowMargin, 0, 0);  // (dx, dy, dw, dh)
  }

  // Find out the nearest display.
  const mozc::Rect display_rect = GetNearestDisplayRect(preedit_rect);

  // Align candidate window.
  // Initialize the position.  We use (left, bottom) of preedit as
  // the top-left position of the window because we want to show the
  // window just below of the preedit.
  const TableLayout *candidate_layout = candidate_window_->GetTableLayout();
  const mozc::Point candidate_zero_point(candidate_layout->GetColumnRect(COLUMN_CANDIDATE).Left(),
                                         0);

  const mozc::Point target_point(preedit_rect.Left(), preedit_rect.Bottom());
  const mozc::Rect candidate_rect = WindowUtil::GetWindowRectForMainWindowFromTargetPointAndPreedit(
      target_point, preedit_rect, candidate_window_->GetWindowSize(), candidate_zero_point,
      display_rect, is_vertical);
  candidate_window_->MoveWindow(OriginPointInCocoaCoord(candidate_rect));

  // Align infolist window
  const mozc::Rect infolist_rect = WindowUtil::GetWindowRectForInfolistWindow(
      infolist_window_->GetWindowSize(), candidate_rect, display_rect);
  infolist_window_->MoveWindow(OriginPointInCocoaCoord(infolist_rect));

  // If there is no need to show cascading window, we just finish the
  // function here.
  if (!command_.output().has_candidate_window() ||
      !(command_.output().candidate_window().candidate_size() > 0) ||
      !command_.output().candidate_window().has_sub_candidate_window()) {
    return;
  }

  // Fix cascading window position
  // 1. starting position is at the focused row
  const commands::CandidateWindow &candidate_window = command_.output().candidate_window();
  const int focused_row = candidate_window.focused_index() - candidate_window.candidate(0).index();
  mozc::Rect focused_rect = candidate_layout->GetRowRect(focused_row);
  // move the focused_rect to the monitor's coordinates
  focused_rect.origin.x += candidate_rect.origin.x;
  focused_rect.origin.y += candidate_rect.origin.y;
  // focused_rect doesn't have the width for scroll bar
  focused_rect.size.width += candidate_layout->GetVScrollBarRect().Width();

  const mozc::Rect cascading_rect = WindowUtil::GetWindowRectForCascadingWindow(
      focused_rect, cascading_window_->GetWindowSize(), mozc::Point(0, 0), display_rect);
  cascading_window_->MoveWindow(OriginPointInCocoaCoord(cascading_rect));
}

}  // namespace mozc::renderer::mac
}  // namespace mozc::renderer
}  // namespace mozc
