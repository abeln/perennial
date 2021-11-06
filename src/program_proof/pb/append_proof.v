From Perennial.program_proof Require Import grove_prelude.
From Goose.github_com.mit_pdos.gokv Require Import pb.

From Perennial.program_proof.pb Require Export append_marshal_proof replica_definitions.

Section append_proof.

Lemma wp_min sl (l:list u64):
  {{{
       is_slice_small sl uint64T 1%Qp l
  }}}
    min (slice_val sl)
  {{{
       (m:u64), RET #m; ⌜length l > 0 → m ∈ l⌝ ∗ ⌜∀ n, n ∈ l → int.Z m ≤ int.Z n⌝ ∗
       is_slice_small sl uint64T 1%Qp l
  }}}.
Proof.
  iIntros (Φ) "Hpre HΦ".
  wp_lam.
  wp_apply (wp_ref_to).
  { naive_solver. }
  iIntros (m_ptr) "Hm".
  wp_pures.
  wp_apply (wp_forSlice (λ j, ∃ (m:u64),
                            "Hm" ∷ m_ptr ↦[uint64T] #m ∗
                            "%H" ∷ ⌜int.Z j = 0 → ∀ (a:u64), int.Z m >= int.Z a⌝ ∗
                            "%HinL" ∷ ⌜int.nat j > 0 → m ∈ l⌝ ∗
                            "%Hmmin" ∷ ⌜∀ n, n ∈ take (int.nat j) l → int.Z m ≤ int.Z n⌝
                        )%I with "[] [$Hpre Hm]").
  {
    iIntros.
    clear Φ.
    iIntros (Φ) "!# [Hpre %Hi] HΦ".
    destruct Hi as [Hi Hilookup].
    iNamed "Hpre".
    wp_pures.
    wp_load.
    wp_pures.
    wp_if_destruct.
    { (* decrease m *)
      admit.
    }
    { (* no need to decrease m *)
      iApply "HΦ".
      iModIntro.
      iExists _; iFrame.
      iPureIntro.
      split.
      {
        intros Hi2 ?.
        exfalso.
        replace (int.Z (word.add i 1)) with (int.Z i + 1) in Hi2 by word.
        word. (* Hi and Hi2 contradictory *)
      }
      split.
      {
        intros _.
        admit.
      }
      {
        intros.
        admit.
      }
    }
  }
  {
    iExists _.
    iFrame "Hm".
    iPureIntro.
    split.
    {
      intros.
      word.
    }
    split.
    {
      intros.
      by exfalso.
    }
    {
      intros.
      exfalso.
      rewrite take_0 in H.
      set_solver.
    }
  }
  iIntros "[HH Hslice]".
  iNamed "HH".
  wp_pures.
  wp_load.
  iApply "HΦ".
  iModIntro.
  iSplitL ""; first admit. (* FIXME: strengthen precond *)
  iDestruct (is_slice_small_sz with "Hslice") as "%Hsz".
  iFrame.
  rewrite -Hsz in Hmmin.
  rewrite firstn_all in Hmmin.
  iPureIntro.
  apply Hmmin.
Admitted.

Lemma wp_ReplicaServer__postAppendRPC (s:loc) (i:u64) conf rid γ (args_ptr:loc) args :
  {{{
       "#HisRepl" ∷ is_ReplicaServer s rid γ ∗
       "#Hconf" ∷ config_ptsto γ args.(AA_cn) conf ∗
       "%Hiconf" ∷ ⌜conf !! int.nat i = Some rid⌝ ∗
       "Hargs" ∷ own_AppendArgs args_ptr args ∗
       "#Hacc_lb" ∷ accepted_lb γ args.(AA_cn) rid args.(AA_log)
  }}}
    ReplicaServer__postAppendRPC #s #i #args_ptr
  {{{
       RET #(); True
  }}}
.
Proof.
  iIntros (Φ) "Hpre HΦ".
  iNamed "Hpre".
  wp_lam.
  wp_pures.

  iNamed "HisRepl".

  wp_loadField.
  wp_apply (acquire_spec with "HmuInv").
  iIntros "[Hlocked Hown]".
  wp_pures.
  iNamed "Hown".
  iNamed "Hargs".
  wp_loadField.
  wp_loadField.
  wp_if_destruct; last first.
  {
    wp_pures.
    wp_loadField.
    wp_apply (release_spec with "[-HΦ]").
    {
      iFrame "HmuInv Hlocked".
      iNext.
      do 9 iExists _. iFrame "∗ #".
      iFrame "Hown".
      done.
    }
    wp_pures.
    by iApply "HΦ".
  }
  wp_loadField.
  assert (isPrimary = true) as ->.
  { admit. (* FIXME: have to add some extra monotonic ghost state to establish this *) }
  iNamed "Hown".
  iDestruct (config_ptsto_agree with "HconfPtsto Hconf") as %HconfAgree.
  rewrite HconfAgree.
  iDestruct (big_sepL2_lookup_1_some with "HmatchIdxAccepted") as %HmatchLookup.
  { done. }
  destruct HmatchLookup as [idx HmatchLookup].
  wp_apply (wp_SliceGet with "[$HmatchIdx_slice]").
  { done. }
  iIntros "HmatchIdx_slice".
  wp_loadField.
  wp_apply (wp_slice_len).
  iDestruct (is_slice_sz with "HopLog_slice") as %HopLogLen.
  wp_if_destruct.
  { (* increase matchIdx[i] *)
    wp_loadField.
    wp_apply (wp_slice_len).
    wp_loadField.
    wp_apply (wp_SliceSet with "[$HmatchIdx_slice]").
    { done. }
    iIntros "HmatchIdx_slice".
    wp_pures.
    wp_loadField.
    set matchIdx':=(<[int.nat i:=log_sl.(Slice.sz)]> matchIdx).
    wp_apply (wp_min with "[$HmatchIdx_slice]").
    iIntros (m) "(%Hm1&%Hm2&HmatchIdx_slice)".
    wp_pures.
    wp_loadField.
    wp_if_destruct.
    { (* commit something! *)
      wp_storeField.
      wp_loadField.

      wp_apply (release_spec with "[> -HΦ]").
      {
        iEval (rewrite -bi.later_intro).
        iFrame "HmuInv Hlocked".
        do 9 iExists _.
        iFrame "∗#".
        iFrame "HprimaryOwnsProposal".

        iSplitL "".
        {
          iMod (do_commit with "[]") as "$"; last done.
          iExists _; iFrame "#".
          (* FIXME: want to use x0 ∈ l to get resource out of [∗ list] x;y ∈ l;l', Φ x y *)
          iDestruct (big_sepL2_lookup_acc with "HmatchIdxAccepted") as "[HH _]".
          { done. }
          { done. }
          admit.
        }

        iSplitL "".
        { admit. (* use the fact that min ≤ matchIdx[0] ≤ length opLog or some such *) }
        iExists _; iFrame "#".
        iDestruct (big_sepL2_insert_acc with "HmatchIdxAccepted") as "HH".
        { done. }
        { done. }
        iFreeze "HH".
        replace (conf) with (<[int.nat i:=rid]> conf); last first.
        { by apply list_insert_id. }
        iThaw "HH".
        unfold matchIdx'.
        iDestruct "HH" as "[Hacc HH]".
        iApply "HH".
        admit. (* Show that take (len AA_log) opLog == args.(AA_log) by virtue of proposal_ptsto *)
      }
      wp_pures.
      by iApply "HΦ".
    }
    wp_pures.
    wp_loadField.
    wp_apply (release_spec with "[-HΦ]").
    {
      iEval (rewrite -bi.later_intro).
      iFrame "HmuInv Hlocked".
      do 9 iExists _.
      iFrame "∗#∗".
      iSplitL ""; first done.
      iExists _; iFrame "#".

      iFreeze "HmatchIdxAccepted".
      replace (conf) with (<[int.nat i:=rid]> conf); last first.
      { by apply list_insert_id. }
      iThaw "HmatchIdxAccepted".
      iDestruct (big_sepL2_insert_acc with "HmatchIdxAccepted") as "[_ HH]".
      { done. }
      { done. }
      iApply "HH".
      admit. (* Show that take (len AA_log) opLog == args.(AA_log) by virtue of proposal_ptsto *)
    }
    wp_pures.
    by iApply "HΦ".
  }
  {
    wp_pures.
    wp_loadField.
    wp_apply (release_spec with "[-HΦ]").
    {
      iFrame "HmuInv Hlocked".
      iNext. do 9 iExists _.
      iFrame "∗#∗".
      iSplitL ""; first done.
      iExists _; iFrame "#".
    }
    wp_pures.
    by iApply "HΦ".
  }
Admitted.

Lemma wp_ReplicaServer__AppendRPC (s:loc) rid γ (args_ptr:loc) args :
  {{{
       "#HisRepl" ∷ is_ReplicaServer s rid γ ∗
       "Hargs" ∷ own_AppendArgs args_ptr args ∗
       "#Hproposal_lb_in" ∷ proposal_lb γ args.(AA_cn) args.(AA_log) ∗
       "#HoldConfMax_in" ∷ oldConfMax γ args.(AA_cn) args.(AA_log) ∗
       "#Hcommit_lb_in" ∷ commit_lb_by γ args.(AA_cn) (take (int.nat args.(AA_commitIdx)) args.(AA_log)) ∗
       "%HcommitLength" ∷ ⌜int.Z args.(AA_commitIdx) < length args.(AA_log)⌝
  }}}
    ReplicaServer__AppendRPC #s #args_ptr
  {{{
       (r:bool), RET #r; ⌜r = true⌝ ∗ accepted_lb γ args.(AA_cn) rid args.(AA_log) ∨ ⌜r = false⌝
  }}}
.
Proof.
  iIntros (Φ) "Hpre HΦ".
  iNamed "Hpre".
  iNamed "HisRepl".
  wp_lam.
  wp_pures.
  wp_loadField.
  wp_apply (acquire_spec with "HmuInv").
  iIntros "[Hlocked Hown]".
  iNamed "Hown".

  wp_pures.
  iNamed "Hargs".
  wp_loadField.
  wp_loadField.

  wp_if_destruct.
  { (* args.cn < s.cn *)
    wp_loadField.
    wp_apply (release_spec with "[-HΦ]").
    {
    iFrame "HmuInv Hlocked". iNext.
    iExists _, _, _, _, _, _, _, _.
    iExists _. (* can only iExists 8 things at a time *)
    iFrame "∗#".
    iFrame "Hown".
    done.
    }
    wp_pures.
    iApply "HΦ".
    iRight.
    done.
  }
  (* args.cn ≥ s.cn *)

  wp_loadField.
  wp_loadField.
  wp_apply (wp_or with "[HopLog HAlog]").
  { iNamedAccu. }
  { by wp_pures. }
  {
    iIntros "% HH"; iNamed "HH".
    wp_loadField.
    wp_apply (wp_slice_len).
    wp_loadField.
    wp_apply (wp_slice_len).
    wp_pures.
    by iFrame.
  }
  iNamed 1.

  iDestruct (is_slice_sz with "HopLog_slice") as %HopLogLen.
  iDestruct (is_slice_sz with "HAlog_slice") as %HALogLen.
  wp_apply (wp_If_join_evar with "[Haccepted HacceptedUnused HopLog HopLog_slice Hcn HAlog HAlog_slice HAcn]").
  {
    iIntros.
    wp_if_destruct; last first.
    { (* won't grow log *)
    iModIntro; iSplitL ""; first done.
    iAssert (∃ opLog_sl' opLog',
              "HopLog" ∷ s ↦[ReplicaServer :: "opLog"] (slice_val opLog_sl') ∗
                       "HopLog_slice" ∷ is_slice opLog_sl' byteT 1 opLog' ∗
                       "Haccepted" ∷ accepted_ptsto γ args.(AA_cn) rid opLog' ∗
                       "HacceptedUnused" ∷ ([∗ set] cn_some ∈ fin_to_set u64, ⌜int.Z cn_some ≤ int.Z args.(AA_cn)⌝
                                                                              ∨ accepted_ptsto γ cn_some rid []) ∗
                       "#Hproposal_lb" ∷ proposal_lb γ args.(AA_cn) opLog' ∗
                       "#HoldConfMax" ∷ oldConfMax γ args.(AA_cn) opLog' ∗
                       "Hcn" ∷ s ↦[ReplicaServer :: "cn"] #args.(AA_cn) ∗
                       "#Hcommit_lb_oldIdx" ∷ commit_lb_by γ args.(AA_cn) (take (int.nat commitIdx) opLog') ∗
                       "%HnewLog" ∷ ⌜args.(AA_log) ⪯ opLog'⌝ ∗
                       "#Hacc_lb" ∷ accepted_lb γ args.(AA_cn) rid args.(AA_log) ∗
                       "%HcommitIdxLeNewLogLen" ∷ ⌜int.Z commitIdx ≤ length opLog'⌝
            )%I with "[HopLog HopLog_slice Haccepted HacceptedUnused Hproposal_lb HoldConfMax Hcn]" as "HH".
    {
      replace (cn) with (args.(AA_cn)); last by word.
      iDestruct (accepted_witness with "Haccepted") as "#Hacc_lb".
      iExists _, _; iFrame "∗#".
      assert (int.nat opLog_sl.(Slice.sz) >= int.nat log_sl.(Slice.sz))%Z as HopLogBigger.
      { word. }

      iDestruct (proposal_lb_comparable with "Hproposal_lb_in Hproposal_lb") as %Hcomparable.
      destruct Hcomparable as [|].
      { (* case 1: args.log ⪯ opLog *)
        iSplitL ""; first done.
        iSplitR ""; last done.
        by iApply accepted_lb_monotonic.
      }
      { (* case 2: opLog ⪯ args.log; this will imply that the two are actually equal *)
        rewrite -HopLogLen in HopLogBigger.
        rewrite -HALogLen in HopLogBigger.
        assert (opLog = args.(AA_log)) as ->.
        { (* FIXME: pure list prefix fact *)
          admit.
        }
        iFrame "#".
        done.
      }
    }
    iClear "HAlog HAcn HAlog_slice".
    iNamedAccu.
    }
    { (* will grow the log *)
      wp_loadField.
      wp_apply (wp_storeField with "HopLog").
      { apply slice_val_ty. }
      iIntros "HopLog".
      wp_pures.
      wp_loadField.
      wp_apply wp_fupd.
      wp_storeField.
      iSplitL ""; first done.
      iExists _, _.
      iFrame "HopLog ∗#".
      (* TODO: Ghost stuff. *)
      (* destruct into cases; in case we increase cn, use oldConfMax to maintain commit_lb *)
      assert (int.Z cn > int.Z args.(AA_cn) ∨ int.Z cn = int.Z args.(AA_cn) ∨ int.Z cn < int.Z args.(AA_cn)) as Htrichotomy.
      { word. }
      destruct Htrichotomy as [Hbad|[Heq|HlargerLog]].
      { exfalso. word. }
      { (* in this case, must have len(args.log) ≥ len(s.cn) *)
        assert (int.nat opLog_sl.(Slice.sz) < int.nat log_sl.(Slice.sz)) as HlargerLog2.
        { word. }
        rewrite -HopLogLen -HALogLen in HlargerLog2.
        assert (cn = args.(AA_cn)) as -> by word.
        iFrame "∗#".
        iDestruct (proposal_lb_comparable with "Hproposal_lb_in Hproposal_lb") as %Hcomparable.
        destruct Heqb0 as [Hbad|HargLogLenLarger].
        { exfalso. word. }
        assert (opLog ⪯ args.(AA_log)) as HargLogLarger.
        { (* TODO: comparable + longer length -> larger log *)
          admit. }
        iMod (accepted_update with "Haccepted") as "Haccepted".
        { done. }
        iDestruct (accepted_witness with "Haccepted") as "#Hacc_lb".
        iFrame "Hacc_lb".
        iSplitL "Haccepted"; first done.
        assert (take (int.nat commitIdx) args.(AA_log) ⪯ take (int.nat commitIdx) opLog).
        { (* TODO: Use the fact that commitIdx ≤ len(opLog) to make this work *)
          admit.
        }
        iSplitR "".
        {
          iApply (commit_lb_by_monotonic with "Hcommit_lb").
          { done. }
          { done. }
        }
        iSplitR ""; first done.
        iPureIntro.
        word.
      }
      { (* args.cn > s.cn: in this case, we want to increase our cn to args.cn *)
        iClear "Haccepted". (* throw away the old accepted↦ *)
        iDestruct (big_sepS_elem_of_acc_impl args.(AA_cn) with "HacceptedUnused") as "[Haccepted Hunused]".
        { set_solver. }
        iDestruct "Haccepted" as "[%Hbad|Haccepted]".
        { exfalso; word. }
        iMod (accepted_update _ _ _ _ args.(AA_log) with "Haccepted") as "Haccepted".
        { admit. }
        iDestruct (accepted_witness with "Haccepted") as "#Hacc_lb".
        iSplitL "Haccepted"; first done.
        iSplitL "Hunused".
        {
          iApply "Hunused".
          {
            iModIntro.
            iIntros (???) "[%Hcase|Hcase]".
            { iLeft. iPureIntro. word. }
            { iFrame. }
          }
          {
            iLeft. iPureIntro. word.
          }
        }
        iFrame "Hacc_lb".

        iDestruct (oldConfMax_commit_lb_by with "HoldConfMax_in Hcommit_lb") as %HlogLe.
        { done. }
        iSplitR ""; last first.
        {
          iSplitL ""; first done.
          iPureIntro.
          admit. (* TODO: Pure fact about lists *)
        }

        iApply (commit_lb_by_monotonic with "Hcommit_lb").
        { word. }
        clear -HlogLe.
        (* TODO: pure fact about lists and prefixes *)
        admit.
      }
    }
  }
  iIntros "HH".
  wp_loadField.
  wp_loadField.

  wp_pures.
  iClear "Hproposal_lb HoldConfMax".
  iRename "Hcommit_lb" into "Hcommit_lb_old".
  iNamed "HH".
  iNamed "HH".
  wp_apply (wp_If_join_evar with "[HcommitIdx HAcommitIdx]").
  {
    iIntros.
    wp_if_destruct.
    { (* args.commitIdx > commitIdx *)
      wp_loadField.
      wp_storeField.
      iSplitL ""; first done.
      iAssert (∃ (commitIdx':u64), "Hcommit" ∷ s ↦[ReplicaServer :: "commitIdx"] #commitIdx' ∗
                                   "#Hcommit_lb" ∷ commit_lb_by γ args.(AA_cn) (take (int.nat commitIdx') opLog') ∗
                                   "%HcommitLeLogLen" ∷ ⌜int.Z commitIdx' ≤ length opLog'⌝
              )%I with "[HcommitIdx]" as "HH".
      {
        iExists _.
        iFrame.
        (* prove that args.(AA_log) ≤ opLog' or that
           opLog' ≤ args.(AA_log);
         *)
        (* Use the fact that args.(AA_log) and opLog' are comparable. *)
        assert ( take (int.nat args.(AA_commitIdx)) opLog' ⪯
                (take (int.nat args.(AA_commitIdx)) args.(AA_log)))%I.
        {
          set (l1:=args.(AA_log)) in *.
          set (l2:=opLog') in *.
          set (e:=int.nat args.(AA_commitIdx)) in *.
          assert (e < length l1) by word.
          clear -H0 HnewLog.
          admit. (* TODO: pure list fact *)
        }
        iSplitR "".
        {
          iApply (commit_lb_by_monotonic with "Hcommit_lb_in").
          { word. }
          done.
        }
        {
          iPureIntro.
          assert (length args.(AA_log) ≤ length opLog').
          { admit. (* TODO: pure fact *) }
          word.
        }
      }
      iNamedAccu.
    }
    { (* args.commitIdx is not larger than commitIdx. boils down to the newly
         proposed value not contradicting the previously committed stuff, the
         proof is done earlier for conveneince. *)
        iModIntro. iSplitL ""; first done.
        iFrame.
        iExists commitIdx.
        iFrame.
        iFrame "#".
        {
          iPureIntro.
          assert (length args.(AA_log) ≤ length opLog').
          { admit. (* TODO: pure fact *) }
          word.
        }
    }
  }
  iIntros "HH".
  iNamed "HH".
  iNamed "HH".
  wp_pures.
  wp_storeField.
  wp_loadField.
  wp_apply (release_spec with "[-HΦ]").
  {
    iFrame "HmuInv Hlocked".
    iNext.
    do 9 iExists _.
    iFrame "∗#".
    done.
  }
  wp_pures.
  iApply "HΦ".
  iLeft.
  iFrame "#".
  by iModIntro.
Admitted.

End append_proof.